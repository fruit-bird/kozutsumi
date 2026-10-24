use std::{
    env,
    io::{ErrorKind, Write as _},
    path::Path,
    process::{Command, Stdio},
};

use crate::{cli::ParcelCommands, config::ParcelConfig};

pub fn default_config() -> String {
    let base = shellexpand::tilde("~/.config/kozutsumi/kozutsumi");
    let yml = format!("{}.yml", base);
    let yaml = format!("{}.yaml", base);

    if Path::new(&yml).exists() { yml } else { yaml }
}

pub fn available_parcels(config: &ParcelConfig) -> String {
    config
        .parcels
        .keys()
        .map(String::as_str)
        .intersperse(", ")
        .collect()
}

#[cfg(feature = "dialog")]
pub fn choose(config_path: &Path, multi: bool) -> anyhow::Result<()> {
    use dialoguer::{FuzzySelect, MultiSelect, theme::ColorfulTheme};

    let config = ParcelConfig::load(config_path)?;
    let parcels = config.parcels.keys().collect::<Vec<_>>();
    if parcels.is_empty() {
        eprintln!("No parcels available. Please add parcels to the configuration file.");
        return Ok(());
    }

    if multi {
        let selection = MultiSelect::with_theme(&ColorfulTheme::default())
            .with_prompt("Select a parcel to open")
            .items(&parcels)
            .interact_opt()?;

        if let Some(indices) = selection {
            for name in indices.iter().map(|&i| parcels[i].to_string()) {
                ParcelCommands::Open { name }.run(config_path)?;
            }
        } else {
            println!("No parcels selected.");
        }
    } else {
        let selection = FuzzySelect::with_theme(&ColorfulTheme::default())
            .with_prompt("Select a parcel to open")
            .items(&parcels)
            .default(0)
            .interact_opt()?;

        if let Some(index) = selection {
            let name = parcels[index].to_string();
            ParcelCommands::Open { name }.run(config_path)?;
        } else {
            println!("No parcel selected.");
        }
    };

    Ok(())
}

pub fn choose_fzf(config_path: &Path, multi: bool, fzf_args: &[String]) -> anyhow::Result<()> {
    let current_exe = env::current_exe()?;
    let config = ParcelConfig::load(config_path)?;
    if config.is_empty() {
        eprintln!("No parcels available. Please add parcels to the configuration file.");
        return Ok(());
    }

    let mut args = vec!["--preview-window=right:60%:wrap"];
    args.extend(fzf_args.iter().map(String::as_str));
    if multi {
        args.push("--multi");
    }

    // The preview runs through `sh -c`, so shell-quote the paths we interpolate.
    let preview = format!(
        "{} --config {} list {{}}",
        shell_quote(&current_exe.to_string_lossy()),
        shell_quote(&config_path.to_string_lossy()),
    );

    let fzf = match Command::new("fzf")
        .args(args)
        .arg("--preview")
        .arg(preview)
        .stdin(Stdio::piped())
        .stdout(Stdio::piped())
        .spawn()
    {
        Ok(child) => child,
        Err(e) if e.kind() == ErrorKind::NotFound => {
            anyhow::bail!("fzf is not installed or not found in PATH");
        }
        Err(e) => return Err(e.into()),
    };

    let mut stdin = fzf.stdin.as_ref().unwrap();
    for parcel in config.parcels.keys() {
        writeln!(stdin, "{}", parcel)?;
    }

    let output = fzf.wait_with_output()?;
    if output.status.success() {
        if output.stdout.is_empty() {
            eprintln!("No parcel selected.");
            return Ok(());
        }

        let selection = String::from_utf8_lossy(&output.stdout);
        for name in selection.lines().map(ToString::to_string) {
            ParcelCommands::Open { name }.run(config_path.as_ref())?;
        }

        Ok(())
    } else {
        match output.status.code() {
            Some(130) | Some(1) => {
                // 130: User cancelled (Ctrl-C)
                //   1: No match found
                eprintln!("No parcel selected.");
                Ok(())
            }
            _ => anyhow::bail!("fzf failed with status: {}", output.status),
        }
    }
}

/// Wrap a string in single quotes for safe interpolation into an `sh -c` command,
/// so paths containing spaces or shell metacharacters survive the fzf preview.
fn shell_quote(s: &str) -> String {
    format!("'{}'", s.replace('\'', r"'\''"))
}
