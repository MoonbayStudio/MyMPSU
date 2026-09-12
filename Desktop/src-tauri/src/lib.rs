use keyring::{Entry, Error as KeyringError};
use tauri_plugin_window_state::StateFlags;

const KEYRING_SERVICE: &str = "ru.moonbaystudio.mympsu.desktop";
const KEYRING_ACCOUNT: &str = "auth-session";

fn auth_entry() -> Result<Entry, String> {
    Entry::new(KEYRING_SERVICE, KEYRING_ACCOUNT).map_err(|error| error.to_string())
}

#[tauri::command]
fn set_auth_token(token: String) -> Result<(), String> {
    if token.trim().is_empty() {
        return Err("Refusing to store an empty token".into());
    }
    auth_entry()?.set_password(&token).map_err(|error| error.to_string())
}

#[tauri::command]
fn get_auth_token() -> Result<Option<String>, String> {
    match auth_entry()?.get_password() {
        Ok(token) => Ok(Some(token)),
        Err(KeyringError::NoEntry) => Ok(None),
        Err(error) => Err(error.to_string()),
    }
}

#[tauri::command]
fn clear_auth_token() -> Result<(), String> {
    match auth_entry()?.delete_credential() {
        Ok(()) | Err(KeyringError::NoEntry) => Ok(()),
        Err(error) => Err(error.to_string()),
    }
}

#[cfg_attr(mobile, tauri::mobile_entry_point)]
pub fn run() {
    tauri::Builder::default()
        .plugin(tauri_plugin_os::init())
        .plugin(tauri_plugin_store::Builder::default().build())
        .plugin(tauri_plugin_notification::init())
        .plugin(
            tauri_plugin_window_state::Builder::default()
                .with_state_flags(StateFlags::all())
                .build(),
        )
        .invoke_handler(tauri::generate_handler![
            set_auth_token,
            get_auth_token,
            clear_auth_token
        ])
        .run(tauri::generate_context!())
        .expect("error while running MyMPSU Desktop");
}
