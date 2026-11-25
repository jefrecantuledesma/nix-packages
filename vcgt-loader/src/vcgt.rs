//! Reading the `vcgt` (video card gamma table) tag of an ICC profile.
//!
//! `vcgt` is Apple's private tag that calibration tools (Spyder, ArgyllCMS,
//! DisplayCAL) use to store the per-channel curves meant for the video card's
//! gamma table. It comes in two forms: a sampled table or a gamma formula.

use std::fmt;

#[derive(Debug, Clone, PartialEq)]
pub enum Curve {
    /// Evenly spaced samples over 0..=1, each in 0..=1.
    Table(Vec<f64>),
    /// `min + (max - min) * x^gamma`
    Formula { gamma: f64, min: f64, max: f64 },
}

impl Curve {
    /// The curve's value at `x` in 0..=1, clamped to 0..=1.
    pub fn eval(&self, x: f64) -> f64 {
        let x = x.clamp(0.0, 1.0);
        let y = match self {
            Curve::Table(samples) => match samples.len() {
                0 => x,
                1 => samples[0],
                n => {
                    let pos = x * (n - 1) as f64;
                    let lo = (pos.floor() as usize).min(n - 1);
                    let hi = (lo + 1).min(n - 1);
                    let frac = pos - lo as f64;
                    samples[lo] + (samples[hi] - samples[lo]) * frac
                }
            },
            Curve::Formula { gamma, min, max } => min + (max - min) * x.powf(*gamma),
        };
        y.clamp(0.0, 1.0)
    }
}

/// Red, green and blue calibration curves.
#[derive(Debug, Clone, PartialEq)]
pub struct Vcgt {
    pub channels: [Curve; 3],
}

impl Vcgt {
    /// The red, green and blue ramps for a gamma table of `size` entries, laid
    /// out the way wlr-gamma-control wants them: all red, then green, then blue.
    pub fn ramps(&self, size: usize) -> Vec<u16> {
        let mut out = Vec::with_capacity(size * 3);
        for curve in &self.channels {
            for i in 0..size {
                let x = if size > 1 { i as f64 / (size - 1) as f64 } else { 0.0 };
                out.push((curve.eval(x) * 65535.0).round() as u16);
            }
        }
        out
    }
}

#[derive(Debug)]
pub enum Error {
    NotIcc,
    Truncated(&'static str),
    NoVcgt,
    Unsupported(String),
}

impl fmt::Display for Error {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Error::NotIcc => write!(f, "not an ICC profile (no 'acsp' signature)"),
            Error::Truncated(what) => write!(f, "profile is truncated ({what})"),
            Error::NoVcgt => write!(
                f,
                "profile has no vcgt tag, so there are no calibration curves to load"
            ),
            Error::Unsupported(what) => write!(f, "unsupported vcgt tag: {what}"),
        }
    }
}

impl std::error::Error for Error {}

fn be_u16(d: &[u8], off: usize, what: &'static str) -> Result<u16, Error> {
    d.get(off..off + 2)
        .map(|b| u16::from_be_bytes([b[0], b[1]]))
        .ok_or(Error::Truncated(what))
}

fn be_u32(d: &[u8], off: usize, what: &'static str) -> Result<u32, Error> {
    d.get(off..off + 4)
        .map(|b| u32::from_be_bytes([b[0], b[1], b[2], b[3]]))
        .ok_or(Error::Truncated(what))
}

/// ICC s15Fixed16Number
fn be_s15f16(d: &[u8], off: usize, what: &'static str) -> Result<f64, Error> {
    Ok(be_u32(d, off, what)? as i32 as f64 / 65536.0)
}

/// Finds and decodes the `vcgt` tag of an ICC profile.
pub fn parse(icc: &[u8]) -> Result<Vcgt, Error> {
    if icc.get(36..40) != Some(b"acsp") {
        return Err(Error::NotIcc);
    }

    let tag_count = be_u32(icc, 128, "tag count")? as usize;
    let mut tag = None;
    for i in 0..tag_count {
        let entry = 132 + 12 * i;
        let sig = icc.get(entry..entry + 4).ok_or(Error::Truncated("tag table"))?;
        if sig == b"vcgt" {
            let off = be_u32(icc, entry + 4, "tag table")? as usize;
            let len = be_u32(icc, entry + 8, "tag table")? as usize;
            let end = off.checked_add(len).ok_or(Error::Truncated("vcgt tag"))?;
            tag = Some(icc.get(off..end).ok_or(Error::Truncated("vcgt tag"))?);
            break;
        }
    }
    let t = tag.ok_or(Error::NoVcgt)?;

    if t.get(0..4) != Some(b"vcgt") {
        return Err(Error::Unsupported("tag data doesn't start with 'vcgt'".into()));
    }

    match be_u32(t, 8, "vcgt type")? {
        // Table
        0 => {
            let channels = be_u16(t, 12, "vcgt header")? as usize;
            let entries = be_u16(t, 14, "vcgt header")? as usize;
            let entry_size = be_u16(t, 16, "vcgt header")? as usize;
            if channels != 1 && channels != 3 {
                return Err(Error::Unsupported(format!("{channels} channels")));
            }
            if entries < 2 {
                return Err(Error::Unsupported(format!("{entries} entries per channel")));
            }
            let max = match entry_size {
                1 => 255.0,
                2 => 65535.0,
                n => return Err(Error::Unsupported(format!("{n}-byte entries"))),
            };

            let data = &t[18.min(t.len())..];
            if data.len() < channels * entries * entry_size {
                return Err(Error::Truncated("vcgt table"));
            }
            let read = |c: usize| -> Curve {
                Curve::Table(
                    (0..entries)
                        .map(|i| {
                            let at = (c * entries + i) * entry_size;
                            let raw = if entry_size == 1 {
                                data[at] as f64
                            } else {
                                u16::from_be_bytes([data[at], data[at + 1]]) as f64
                            };
                            raw / max
                        })
                        .collect(),
                )
            };
            let channels = if channels == 1 {
                let c = read(0);
                [c.clone(), c.clone(), c]
            } else {
                [read(0), read(1), read(2)]
            };
            Ok(Vcgt { channels })
        }
        // Formula: gamma, min, max for each of red, green, blue
        1 => {
            let curve = |c: usize| -> Result<Curve, Error> {
                let base = 12 + c * 12;
                Ok(Curve::Formula {
                    gamma: be_s15f16(t, base, "vcgt formula")?,
                    min: be_s15f16(t, base + 4, "vcgt formula")?,
                    max: be_s15f16(t, base + 8, "vcgt formula")?,
                })
            };
            Ok(Vcgt { channels: [curve(0)?, curve(1)?, curve(2)?] })
        }
        n => Err(Error::Unsupported(format!("type {n}"))),
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    /// A minimal profile: header with 'acsp', one tag (vcgt) right after the tag table.
    fn profile(vcgt: &[u8]) -> Vec<u8> {
        let mut p = vec![0u8; 128];
        p[36..40].copy_from_slice(b"acsp");
        p.extend_from_slice(&1u32.to_be_bytes());
        p.extend_from_slice(b"vcgt");
        p.extend_from_slice(&144u32.to_be_bytes());
        p.extend_from_slice(&(vcgt.len() as u32).to_be_bytes());
        p.extend_from_slice(vcgt);
        p
    }

    fn table(channels: u16, entries: &[&[u16]]) -> Vec<u8> {
        let mut t = b"vcgt\0\0\0\0".to_vec();
        t.extend_from_slice(&0u32.to_be_bytes());
        t.extend_from_slice(&channels.to_be_bytes());
        t.extend_from_slice(&(entries[0].len() as u16).to_be_bytes());
        t.extend_from_slice(&2u16.to_be_bytes());
        for ch in entries {
            for v in *ch {
                t.extend_from_slice(&v.to_be_bytes());
            }
        }
        t
    }

    #[test]
    fn table_is_resampled_to_gamma_size() {
        let v = parse(&profile(&table(
            3,
            &[&[0, 65535], &[0, 32768], &[65535, 0]],
        )))
        .unwrap();
        let r = v.ramps(3);
        assert_eq!(r, vec![0, 32768, 65535, 0, 16384, 32768, 65535, 32768, 0]);
    }

    #[test]
    fn one_channel_table_applies_to_all() {
        let v = parse(&profile(&table(1, &[&[0, 0, 65535]]))).unwrap();
        assert_eq!(v.channels[0], v.channels[2]);
        assert_eq!(v.ramps(5)[..5], [0, 0, 0, 32768, 65535]);
    }

    #[test]
    fn formula() {
        let mut t = b"vcgt\0\0\0\0".to_vec();
        t.extend_from_slice(&1u32.to_be_bytes());
        for (g, lo, hi) in [(1.0, 0.0, 1.0), (2.0, 0.0, 1.0), (1.0, 0.25, 0.75)] {
            for v in [g, lo, hi] {
                t.extend_from_slice(&((v * 65536.0) as i32).to_be_bytes());
            }
        }
        let v = parse(&profile(&t)).unwrap();
        assert_eq!(v.ramps(3), vec![0, 32768, 65535, 0, 16384, 65535, 16384, 32768, 49151]);
    }

    #[test]
    fn rejects_garbage() {
        assert!(matches!(parse(b"nope"), Err(Error::NotIcc)));
        let mut no_vcgt = profile(&table(1, &[&[0, 65535]]));
        no_vcgt[132..136].copy_from_slice(b"desc");
        assert!(matches!(parse(&no_vcgt), Err(Error::NoVcgt)));
        let mut short = profile(&table(3, &[&[0, 65535], &[0, 65535], &[0, 65535]]));
        short.truncate(short.len() - 4);
        assert!(parse(&short).is_err());
    }
}
