//! vcgt-loader: put an ICC profile's calibration curves (its `vcgt` tag) into a
//! wlroots compositor's hardware gamma table, through wlr-gamma-control.
//!
//! This is the Wayland counterpart of `xcalib`/`dispwin -L`. Sway's own
//! `output ... color_profile icc` needs the Vulkan renderer and ignores `vcgt`;
//! this works with any renderer, as long as the output has a gamma table.
//!
//! The compositor drops the curves as soon as the client that set them goes
//! away, so this keeps running. When an output disappears (unplugged, or
//! disabled with `swaymsg output X disable`) and comes back, the curves are set
//! again.

mod vcgt;

use std::fs::File;
use std::io::Write;
use std::os::fd::AsFd;
use std::process::ExitCode;

use rustix::fs::{memfd_create, MemfdFlags};
use wayland_client::protocol::{wl_output, wl_registry};
use wayland_client::{delegate_noop, Connection, Dispatch, Proxy, QueueHandle};
use wayland_protocols_wlr::gamma_control::v1::client::{
    zwlr_gamma_control_manager_v1::ZwlrGammaControlManagerV1,
    zwlr_gamma_control_v1::{self, ZwlrGammaControlV1},
};

const USAGE: &str = "\
Usage: vcgt-loader [--output NAME]... PROFILE.icc
       vcgt-loader --print PROFILE.icc

Loads the profile's vcgt calibration curves into the gamma table of each named
output (every output if no --output is given) and keeps them there until it is
stopped. Only one program can set an output's gamma at a time, so this can't
run alongside gammastep, wlsunset or similar tools.

  -o, --output NAME   only this output, e.g. LVDS-1 (repeatable)
  -p, --print         show the curves and exit, without touching the display
  -h, --help          show this help";

fn log(msg: impl AsRef<str>) {
    eprintln!("vcgt-loader: {}", msg.as_ref());
}

struct Output {
    /// The registry name of the wl_output global
    global: u32,
    wl_output: wl_output::WlOutput,
    name: Option<String>,
    /// Seen the first `done`, so `name` is final
    ready: bool,
    control: Option<ZwlrGammaControlV1>,
    /// Gave up on this global (the compositor refused or dropped our curves)
    failed: bool,
    /// The ramps handed to the compositor; kept open until the control goes
    ramp_file: Option<File>,
}

impl Output {
    fn label(&self) -> String {
        self.name.clone().unwrap_or_else(|| format!("output {}", self.global))
    }
}

struct App {
    curves: vcgt::Vcgt,
    targets: Vec<String>,
    manager: Option<ZwlrGammaControlManagerV1>,
    outputs: Vec<Output>,
}

impl App {
    fn wanted(&self, o: &Output) -> bool {
        if self.targets.is_empty() {
            return true;
        }
        o.name.as_ref().is_some_and(|n| self.targets.contains(n))
    }

    fn start_all(&mut self, qh: &QueueHandle<Self>) {
        let globals: Vec<u32> = self.outputs.iter().map(|o| o.global).collect();
        for g in globals {
            self.start(g, qh);
        }
    }

    /// Asks for the output's gamma control; the curves go in on `gamma_size`.
    fn start(&mut self, global: u32, qh: &QueueHandle<Self>) {
        let Some(manager) = self.manager.clone() else { return };
        let Some(i) = self.outputs.iter().position(|o| o.global == global) else { return };
        if !self.outputs[i].ready || !self.wanted(&self.outputs[i]) {
            return;
        }
        let o = &mut self.outputs[i];
        if o.control.is_some() || o.failed {
            return;
        }
        o.control = Some(manager.get_gamma_control(&o.wl_output, qh, global));
    }

    fn apply(&mut self, global: u32, size: usize) {
        let ramps = self.curves.ramps(size);
        let Some(o) = self.outputs.iter_mut().find(|o| o.global == global) else { return };
        let Some(control) = o.control.clone() else { return };

        let file = memfd_create("vcgt-loader-ramps", MemfdFlags::CLOEXEC)
            .map(File::from)
            .map_err(std::io::Error::from)
            .and_then(|mut f| {
                let bytes: Vec<u8> = ramps.iter().flat_map(|v| v.to_ne_bytes()).collect();
                f.write_all(&bytes)?;
                Ok(f)
            });
        match file {
            Ok(f) => {
                control.set_gamma(f.as_fd());
                o.ramp_file = Some(f);
                log(format!("loaded calibration curves on {} ({size}-entry gamma table)", o.label()));
            }
            Err(e) => {
                log(format!("couldn't write the gamma ramps for {}: {e}", o.label()));
                control.destroy();
                o.control = None;
                o.failed = true;
            }
        }
    }
}

impl Dispatch<wl_registry::WlRegistry, ()> for App {
    fn event(
        app: &mut Self,
        registry: &wl_registry::WlRegistry,
        event: wl_registry::Event,
        _: &(),
        _: &Connection,
        qh: &QueueHandle<Self>,
    ) {
        match event {
            wl_registry::Event::Global { name, interface, version } => {
                if interface == wl_output::WlOutput::interface().name {
                    // v4 adds the `name` event (e.g. "LVDS-1")
                    let wl_output = registry.bind(name, version.min(4), qh, name);
                    app.outputs.push(Output {
                        global: name,
                        wl_output,
                        name: None,
                        ready: false,
                        control: None,
                        failed: false,
                        ramp_file: None,
                    });
                } else if interface == ZwlrGammaControlManagerV1::interface().name {
                    app.manager = Some(registry.bind(name, 1, qh, ()));
                }
            }
            wl_registry::Event::GlobalRemove { name } => {
                let Some(i) = app.outputs.iter().position(|o| o.global == name) else { return };
                let o = app.outputs.remove(i);
                let label = o.label();
                // The compositor keeps our gamma control around while the output
                // is disabled, and refuses a second one when it comes back, so
                // let go of it now.
                if let Some(control) = o.control {
                    control.destroy();
                    log(format!("{label} went away; will reload when it comes back"));
                }
                if o.wl_output.version() >= 3 {
                    o.wl_output.release();
                }
            }
            _ => {}
        }
    }
}

impl Dispatch<wl_output::WlOutput, u32> for App {
    fn event(
        app: &mut Self,
        _: &wl_output::WlOutput,
        event: wl_output::Event,
        global: &u32,
        _: &Connection,
        qh: &QueueHandle<Self>,
    ) {
        let Some(o) = app.outputs.iter_mut().find(|o| o.global == *global) else { return };
        match event {
            wl_output::Event::Name { name } => o.name = Some(name),
            wl_output::Event::Done => {
                o.ready = true;
                app.start(*global, qh);
            }
            _ => {}
        }
    }
}

impl Dispatch<ZwlrGammaControlV1, u32> for App {
    fn event(
        app: &mut Self,
        control: &ZwlrGammaControlV1,
        event: zwlr_gamma_control_v1::Event,
        global: &u32,
        _: &Connection,
        _: &QueueHandle<Self>,
    ) {
        match event {
            zwlr_gamma_control_v1::Event::GammaSize { size } => app.apply(*global, size as usize),
            zwlr_gamma_control_v1::Event::Failed => {
                control.destroy();
                if let Some(o) = app.outputs.iter_mut().find(|o| o.global == *global) {
                    log(format!(
                        "the compositor refused or dropped the curves on {} (no gamma table, \
                         or another program such as gammastep already controls it)",
                        o.label()
                    ));
                    o.control = None;
                    o.ramp_file = None;
                    o.failed = true;
                }
            }
            _ => {}
        }
    }
}

delegate_noop!(App: ZwlrGammaControlManagerV1);

fn print_curves(curves: &vcgt::Vcgt) {
    for (label, curve) in ["red", "green", "blue"].iter().zip(&curves.channels) {
        let kind = match curve {
            vcgt::Curve::Table(s) => format!("{}-entry table", s.len()),
            vcgt::Curve::Formula { gamma, min, max } => {
                format!("formula: gamma {gamma:.3}, min {min:.3}, max {max:.3}")
            }
        };
        let points: Vec<String> = [0.0, 0.25, 0.5, 0.75, 1.0]
            .iter()
            .map(|&x| format!("{:.3}", curve.eval(x)))
            .collect();
        println!("{label:>5}: {}  ({kind})", points.join("  "));
    }
    println!("        (values at 0%, 25%, 50%, 75% and 100% input)");
}

fn main() -> ExitCode {
    let mut targets = Vec::new();
    let mut print = false;
    let mut profile = None;

    let mut args = std::env::args().skip(1);
    while let Some(arg) = args.next() {
        match arg.as_str() {
            "-h" | "--help" => {
                println!("{USAGE}");
                return ExitCode::SUCCESS;
            }
            "-p" | "--print" => print = true,
            "-o" | "--output" => match args.next() {
                Some(name) => targets.push(name),
                None => {
                    log("--output needs an output name");
                    return ExitCode::from(2);
                }
            },
            _ if arg.starts_with("--output=") => targets.push(arg["--output=".len()..].to_string()),
            _ if arg.starts_with('-') && arg != "-" => {
                log(format!("unknown option {arg}\n\n{USAGE}"));
                return ExitCode::from(2);
            }
            _ if profile.is_none() => profile = Some(arg),
            _ => {
                log(format!("only one profile, please\n\n{USAGE}"));
                return ExitCode::from(2);
            }
        }
    }
    let Some(profile) = profile else {
        log(format!("no profile given\n\n{USAGE}"));
        return ExitCode::from(2);
    };

    let curves = match std::fs::read(&profile)
        .map_err(|e| e.to_string())
        .and_then(|d| vcgt::parse(&d).map_err(|e| e.to_string()))
    {
        Ok(c) => c,
        Err(e) => {
            log(format!("{profile}: {e}"));
            return ExitCode::FAILURE;
        }
    };

    if print {
        print_curves(&curves);
        return ExitCode::SUCCESS;
    }

    let conn = match Connection::connect_to_env() {
        Ok(c) => c,
        Err(e) => {
            log(format!("can't connect to the Wayland compositor: {e}"));
            return ExitCode::FAILURE;
        }
    };
    let mut queue = conn.new_event_queue();
    let qh = queue.handle();
    conn.display().get_registry(&qh, ());

    let mut app = App { curves, targets, manager: None, outputs: Vec::new() };

    // First roundtrip: globals. Second: the outputs' names.
    for _ in 0..2 {
        if let Err(e) = queue.roundtrip(&mut app) {
            log(format!("Wayland error: {e}"));
            return ExitCode::FAILURE;
        }
    }
    if app.manager.is_none() {
        log("the compositor doesn't support wlr-gamma-control (needs sway or another wlroots compositor)");
        return ExitCode::FAILURE;
    }
    app.start_all(&qh);
    for t in &app.targets {
        if !app.outputs.iter().any(|o| o.name.as_ref() == Some(t)) {
            log(format!("no output named {t} right now; waiting for it"));
        }
    }

    loop {
        if let Err(e) = queue.blocking_dispatch(&mut app) {
            // Normally just the compositor exiting, so not an error
            log(format!("Wayland connection closed ({e}); exiting"));
            return ExitCode::SUCCESS;
        }
    }
}
