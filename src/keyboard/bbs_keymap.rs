//! BBS-Remote cross-platform Key Mapping Engine (macOS & Windows).
//! Supports 500+ system, productivity, creative, and gaming key mappings
//! across both rdev native grab (Input source 1) and Flutter FFI (Input source 2).

use std::collections::HashMap;
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::{Arc, Mutex, RwLock};

use base::message_proto::{ControlKey, KeyEvent, KeyboardMode};
use hbb_common::log;
use rdev::{Event, EventType, Key};
use serde::{Deserialize, Serialize};

const BBS_KEYMAP_CONFIG_KEY: &str = "bbs-key-mappings";

static INITIALIZED: AtomicBool = AtomicBool::new(false);

lazy_static::lazy_static! {
    static ref KEYMAP_CACHE: RwLock<Arc<BbsKeyMapConfig>> =
        RwLock::new(Arc::new(BbsKeyMapConfig::default()));
    static ref ACTIVE_REMAPS: Mutex<HashMap<Key, ActiveRemap>> =
        Mutex::new(HashMap::new());
}

#[derive(Clone)]
enum ActiveRemap {
    /// Chord remap: re-fires `press = true` on OS key-repeat and consumes KeyRelease.
    Chord(Option<KeyEvent>),
    /// Single-key hold remap (e.g. gaming movement/crouch/numpad): sends `down = false` on KeyRelease.
    Hold(KeyEvent),
}

#[derive(Debug, Clone, Default, Serialize, Deserialize)]
pub struct BbsKeyMapRule {
    #[serde(default)]
    pub peer: String,
    #[serde(default)]
    pub src_key: String,
    #[serde(default)]
    pub src_ctrl: bool,
    #[serde(default)]
    pub src_alt: bool,
    #[serde(default)]
    pub src_shift: bool,
    #[serde(default)]
    pub src_meta: bool,
    #[serde(default)]
    pub dst_key: String,
    #[serde(default)]
    pub dst_ctrl: bool,
    #[serde(default)]
    pub dst_alt: bool,
    #[serde(default)]
    pub dst_shift: bool,
    #[serde(default)]
    pub dst_meta: bool,
}

impl BbsKeyMapRule {
    #[inline]
    fn src_has_mods(&self) -> bool {
        self.src_ctrl || self.src_alt || self.src_shift || self.src_meta
    }

    #[inline]
    fn dst_has_mods(&self) -> bool {
        self.dst_ctrl || self.dst_alt || self.dst_shift || self.dst_meta
    }
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct BbsKeyMapConfig {
    #[serde(default = "default_true")]
    pub enabled: bool,
    #[serde(default)]
    pub rules: Vec<BbsKeyMapRule>,
}

fn default_true() -> bool {
    true
}

impl Default for BbsKeyMapConfig {
    fn default() -> Self {
        Self {
            enabled: true,
            rules: Vec::new(),
        }
    }
}

pub fn reload_from_config() {
    INITIALIZED.store(true, Ordering::SeqCst);
    let raw = hbb_common::config::LocalConfig::get_option(BBS_KEYMAP_CONFIG_KEY);
    let parsed: BbsKeyMapConfig = if raw.is_empty() {
        BbsKeyMapConfig::default()
    } else {
        match serde_json::from_str(&raw) {
            Ok(cfg) => cfg,
            Err(e) => {
                log::warn!("Failed to parse bbs-key-mappings config: {}", e);
                BbsKeyMapConfig::default()
            }
        }
    };
    if let Ok(mut guard) = KEYMAP_CACHE.write() {
        *guard = Arc::new(parsed);
    }
    if let Ok(mut active) = ACTIVE_REMAPS.lock() {
        active.clear();
    }
}

#[inline]
fn current_config() -> Arc<BbsKeyMapConfig> {
    if !INITIALIZED.load(Ordering::Relaxed) {
        reload_from_config();
    }
    match KEYMAP_CACHE.read() {
        Ok(g) => Arc::clone(&g),
        Err(poison) => Arc::clone(&poison.into_inner()),
    }
}

#[inline]
fn peer_matches(rule_peer: &str, actual_peer_lower: &str) -> bool {
    if rule_peer.is_empty() || rule_peer == "all" {
        return true;
    }
    match rule_peer {
        "windows" => actual_peer_lower.contains("win"),
        "macos" => actual_peer_lower.contains("mac") || actual_peer_lower.contains("darwin"),
        "linux" => actual_peer_lower.contains("linux"),
        other => actual_peer_lower.contains(other),
    }
}

fn rdev_key_to_name(key: Key) -> Option<&'static str> {
    Some(match key {
        Key::KeyA => "a",
        Key::KeyB => "b",
        Key::KeyC => "c",
        Key::KeyD => "d",
        Key::KeyE => "e",
        Key::KeyF => "f",
        Key::KeyG => "g",
        Key::KeyH => "h",
        Key::KeyI => "i",
        Key::KeyJ => "j",
        Key::KeyK => "k",
        Key::KeyL => "l",
        Key::KeyM => "m",
        Key::KeyN => "n",
        Key::KeyO => "o",
        Key::KeyP => "p",
        Key::KeyQ => "q",
        Key::KeyR => "r",
        Key::KeyS => "s",
        Key::KeyT => "t",
        Key::KeyU => "u",
        Key::KeyV => "v",
        Key::KeyW => "w",
        Key::KeyX => "x",
        Key::KeyY => "y",
        Key::KeyZ => "z",
        Key::Num0 => "digit0",
        Key::Num1 => "digit1",
        Key::Num2 => "digit2",
        Key::Num3 => "digit3",
        Key::Num4 => "digit4",
        Key::Num5 => "digit5",
        Key::Num6 => "digit6",
        Key::Num7 => "digit7",
        Key::Num8 => "digit8",
        Key::Num9 => "digit9",
        Key::F1 => "f1",
        Key::F2 => "f2",
        Key::F3 => "f3",
        Key::F4 => "f4",
        Key::F5 => "f5",
        Key::F6 => "f6",
        Key::F7 => "f7",
        Key::F8 => "f8",
        Key::F9 => "f9",
        Key::F10 => "f10",
        Key::F11 => "f11",
        Key::F12 => "f12",
        Key::Return => "enter",
        Key::KpReturn => "kp_enter",
        Key::Escape => "escape",
        Key::Backspace => "backspace",
        Key::Delete => "delete",
        Key::Tab => "tab",
        Key::Space => "space",
        Key::CapsLock => "caps_lock",
        Key::LeftArrow => "arrow_left",
        Key::RightArrow => "arrow_right",
        Key::UpArrow => "arrow_up",
        Key::DownArrow => "arrow_down",
        Key::Home => "home",
        Key::End => "end",
        Key::PageUp => "page_up",
        Key::PageDown => "page_down",
        Key::Insert => "insert",
        Key::PrintScreen | Key::Print => "print_screen",
        Key::ScrollLock => "scroll_lock",
        Key::Pause => "pause",
        Key::NumLock => "num_lock",
        Key::Minus => "minus",
        Key::Equal => "equal",
        Key::LeftBracket => "bracket_left",
        Key::RightBracket => "bracket_right",
        Key::BackSlash => "backslash",
        Key::SemiColon => "semicolon",
        Key::Quote => "quote",
        Key::BackQuote => "backquote",
        Key::Comma => "comma",
        Key::Dot => "period",
        Key::Slash => "slash",
        Key::Kp0 => "kp_0",
        Key::Kp1 => "kp_1",
        Key::Kp2 => "kp_2",
        Key::Kp3 => "kp_3",
        Key::Kp4 => "kp_4",
        Key::Kp5 => "kp_5",
        Key::Kp6 => "kp_6",
        Key::Kp7 => "kp_7",
        Key::Kp8 => "kp_8",
        Key::Kp9 => "kp_9",
        Key::KpPlus => "kp_add",
        Key::KpMinus => "kp_subtract",
        Key::KpMultiply => "kp_multiply",
        Key::KpDivide => "kp_divide",
        Key::KpDecimal => "kp_decimal",
        _ => return None,
    })
}

fn fill_target_union(evt: &mut KeyEvent, dst_key: &str) -> bool {
    let ck = match dst_key {
        "enter" => Some(ControlKey::Return),
        "kp_enter" => Some(ControlKey::NumpadEnter),
        "escape" => Some(ControlKey::Escape),
        "backspace" => Some(ControlKey::Backspace),
        "delete" => Some(ControlKey::Delete),
        "tab" => Some(ControlKey::Tab),
        "space" => Some(ControlKey::Space),
        "caps_lock" => Some(ControlKey::CapsLock),
        "arrow_left" => Some(ControlKey::LeftArrow),
        "arrow_right" => Some(ControlKey::RightArrow),
        "arrow_up" => Some(ControlKey::UpArrow),
        "arrow_down" => Some(ControlKey::DownArrow),
        "home" => Some(ControlKey::Home),
        "end" => Some(ControlKey::End),
        "page_up" => Some(ControlKey::PageUp),
        "page_down" => Some(ControlKey::PageDown),
        "insert" => Some(ControlKey::Insert),
        "print_screen" => Some(ControlKey::Snapshot),
        "scroll_lock" => Some(ControlKey::Scroll),
        "pause" => Some(ControlKey::Pause),
        "num_lock" => Some(ControlKey::NumLock),
        "f1" => Some(ControlKey::F1),
        "f2" => Some(ControlKey::F2),
        "f3" => Some(ControlKey::F3),
        "f4" => Some(ControlKey::F4),
        "f5" => Some(ControlKey::F5),
        "f6" => Some(ControlKey::F6),
        "f7" => Some(ControlKey::F7),
        "f8" => Some(ControlKey::F8),
        "f9" => Some(ControlKey::F9),
        "f10" => Some(ControlKey::F10),
        "f11" => Some(ControlKey::F11),
        "f12" => Some(ControlKey::F12),
        "kp_0" => Some(ControlKey::Numpad0),
        "kp_1" => Some(ControlKey::Numpad1),
        "kp_2" => Some(ControlKey::Numpad2),
        "kp_3" => Some(ControlKey::Numpad3),
        "kp_4" => Some(ControlKey::Numpad4),
        "kp_5" => Some(ControlKey::Numpad5),
        "kp_6" => Some(ControlKey::Numpad6),
        "kp_7" => Some(ControlKey::Numpad7),
        "kp_8" => Some(ControlKey::Numpad8),
        "kp_9" => Some(ControlKey::Numpad9),
        "kp_add" => Some(ControlKey::Add),
        "kp_subtract" => Some(ControlKey::Subtract),
        "kp_multiply" => Some(ControlKey::Multiply),
        "kp_divide" => Some(ControlKey::Divide),
        "kp_decimal" => Some(ControlKey::Decimal),
        "shift" => Some(ControlKey::Shift),
        "ctrl" => Some(ControlKey::Control),
        "alt" => Some(ControlKey::Alt),
        "meta" => Some(ControlKey::Meta),
        _ => None,
    };
    if let Some(control) = ck {
        evt.set_control_key(control);
        return true;
    }

    let chr_opt: Option<char> = match dst_key {
        "digit0" => Some('0'),
        "digit1" => Some('1'),
        "digit2" => Some('2'),
        "digit3" => Some('3'),
        "digit4" => Some('4'),
        "digit5" => Some('5'),
        "digit6" => Some('6'),
        "digit7" => Some('7'),
        "digit8" => Some('8'),
        "digit9" => Some('9'),
        "minus" => Some('-'),
        "equal" => Some('='),
        "bracket_left" => Some('['),
        "bracket_right" => Some(']'),
        "backslash" => Some('\\'),
        "semicolon" => Some(';'),
        "quote" => Some('\''),
        "backquote" => Some('`'),
        "comma" => Some(','),
        "period" => Some('.'),
        "slash" => Some('/'),
        s if s.len() == 1 => s.chars().next().map(|c| c.to_ascii_lowercase()),
        _ => None,
    };
    if let Some(c) = chr_opt {
        evt.set_chr(c as u32);
        return true;
    }
    false
}

#[cfg(feature = "flutter")]
pub fn try_remap(
    session_id: Option<&hbb_common::SessionID>,
    event: &Event,
    keyboard_mode: &str,
    peer: impl FnOnce() -> String,
    send: impl Fn(&KeyEvent),
) -> bool {
    // 1. Handle ongoing active remaps (key release or OS key-repeat)
    match event.event_type {
        EventType::KeyRelease(phys_key) => {
            if let Some(active) = ACTIVE_REMAPS.lock().unwrap().remove(&phys_key) {
                if let ActiveRemap::Hold(up_evt) = active {
                    send(&up_evt);
                }
                return true;
            }
            return false;
        }
        EventType::KeyPress(phys_key) => {
            if let Some(active) = ACTIVE_REMAPS.lock().unwrap().get(&phys_key).cloned() {
                if let ActiveRemap::Chord(Some(repeat_evt)) = active {
                    send(&repeat_evt);
                }
                return true;
            }
        }
        _ => return false,
    }

    let EventType::KeyPress(phys_key) = event.event_type else {
        return false;
    };

    let cfg = current_config();
    if !cfg.enabled || cfg.rules.is_empty() {
        return false;
    }

    let Some(key_name) = rdev_key_to_name(phys_key) else {
        return false;
    };

    let (alt, ctrl, shift, command) =
        crate::keyboard::client::get_modifiers_state(false, false, false, false);
    let peer_lower = peer();

    let matched = cfg.rules.iter().find(|r| {
        r.src_key == key_name
            && r.src_ctrl == ctrl
            && r.src_alt == alt
            && r.src_shift == shift
            && r.src_meta == command
            && peer_matches(&r.peer, &peer_lower)
    });

    let Some(rule) = matched else {
        return false;
    };

    let resolved;
    let sid = match session_id {
        Some(id) => id,
        None => {
            resolved = crate::flutter::get_cur_session_id();
            &resolved
        }
    };

    // Release any physically held modifiers on the remote before injecting the mapped target
    if rule.src_has_mods() {
        super::shortcuts::release_remote_keys(sid, keyboard_mode, &peer_lower, &send);
    }

    // Special system actions
    if rule.dst_key == "lock_screen" {
        let evt = crate::keyboard::client::event_lock_screen();
        send(&evt);
        ACTIVE_REMAPS
            .lock()
            .unwrap()
            .insert(phys_key, ActiveRemap::Chord(None));
        return true;
    }
    if rule.dst_key == "ctrl_alt_del" {
        let peer_cap = if peer_lower.contains("win") {
            "Windows"
        } else {
            "Other"
        };
        let evt = crate::keyboard::client::event_ctrl_alt_del(peer_cap);
        send(&evt);
        ACTIVE_REMAPS
            .lock()
            .unwrap()
            .insert(phys_key, ActiveRemap::Chord(None));
        return true;
    }

    let mut base_evt = KeyEvent::new();
    if !fill_target_union(&mut base_evt, &rule.dst_key) {
        return false;
    }
    base_evt.mode = KeyboardMode::Legacy.into();

    // Pure single-key remap (no source or target modifiers): hold down until physical release
    if !rule.src_has_mods() && !rule.dst_has_mods() {
        let mut down_evt = base_evt.clone();
        down_evt.down = true;
        down_evt.press = false;
        let mut up_evt = base_evt;
        up_evt.down = false;
        up_evt.press = false;
        send(&down_evt);
        ACTIVE_REMAPS
            .lock()
            .unwrap()
            .insert(phys_key, ActiveRemap::Hold(up_evt));
        return true;
    }

    // Chord remap: atomic press with target modifiers
    crate::keyboard::client::legacy_modifiers(
        &mut base_evt,
        rule.dst_alt,
        rule.dst_ctrl,
        rule.dst_shift,
        rule.dst_meta,
    );
    base_evt.press = true;
    send(&base_evt);
    ACTIVE_REMAPS
        .lock()
        .unwrap()
        .insert(phys_key, ActiveRemap::Chord(Some(base_evt)));
    true
}
