use super::{PrivacyMode, PrivacyModeState};
use hbb_common::{anyhow::anyhow, ResultType};
use std::ffi::CString;

extern "C" {
    fn MacConfigurePrivacyScreen(use_screensaver: bool, custom_text: *const std::os::raw::c_char);
    fn MacSetPrivacyMode(on: bool) -> bool;
}

pub const PRIVACY_MODE_IMPL: &str = "privacy_mode_impl_macos";

pub struct PrivacyModeImpl {
    impl_key: String,
    conn_id: i32,
}

impl PrivacyModeImpl {
    pub fn new(impl_key: &str) -> Self {
        Self {
            impl_key: impl_key.to_owned(),
            conn_id: 0,
        }
    }
}

impl PrivacyMode for PrivacyModeImpl {
    fn is_async_privacy_mode(&self) -> bool {
        false
    }

    fn init(&self) -> ResultType<()> {
        Ok(())
    }

    fn clear(&mut self) {
        unsafe {
            MacSetPrivacyMode(false);
        }
        self.conn_id = 0;
    }

    fn turn_on_privacy(&mut self, conn_id: i32) -> ResultType<bool> {
        if self.check_on_conn_id(conn_id)? {
            return Ok(true);
        }
        let style = hbb_common::config::LocalConfig::get_option("bbs_privacy_style");
        let use_screensaver = style == "screensaver";
        let raw_text = hbb_common::config::LocalConfig::get_option("bbs_privacy_text");
        let banner_text = if raw_text.trim().is_empty() {
            "正在远程安全办公中 · 请勿触碰设备".to_owned()
        } else {
            raw_text
        };
        let c_text = CString::new(banner_text.replace('\0', "")).unwrap_or_default();
        let success = unsafe {
            MacConfigurePrivacyScreen(use_screensaver, c_text.as_ptr());
            MacSetPrivacyMode(true)
        };
        if !success {
            return Err(anyhow!("Failed to turn on privacy mode"));
        }
        self.conn_id = conn_id;
        Ok(true)
    }

    fn turn_off_privacy(&mut self, conn_id: i32, _state: Option<PrivacyModeState>) -> ResultType<()> {
        // Note: The `_state` parameter is intentionally ignored on macOS.
        // On Windows, it's used to notify the connection manager about privacy mode state changes
        // (see win_topmost_window.rs). macOS currently has a simpler single-mode implementation
        // without the need for such cross-component state synchronization.
        self.check_off_conn_id(conn_id)?;
        let success = unsafe { MacSetPrivacyMode(false) };
        if !success {
            return Err(anyhow!("Failed to turn off privacy mode"));
        }
        self.conn_id = 0;
        Ok(())
    }

    fn pre_conn_id(&self) -> i32 {
        self.conn_id
    }

    fn get_impl_key(&self) -> &str {
        &self.impl_key
    }
}

impl Drop for PrivacyModeImpl {
    fn drop(&mut self) {
        // Use the same cleanup logic as other code paths to keep conn_id consistent
        // and ensure all cleanup is centralized in one place.
        self.clear();
    }
}

/// Most closes lock before the connection loop turns privacy mode off, and a lock shortcut
/// injected while the tap and the blackout are torn down can be lost (#15875).
pub fn turn_off_before_lock(conn_id: i32) {
    if super::get_privacy_mode_conn_id() == Some(conn_id) {
        if let Some(Err(e)) = super::turn_off_privacy(conn_id, None) {
            hbb_common::log::error!("Failed to turn off privacy mode before locking: {}", e);
        }
    }
}
