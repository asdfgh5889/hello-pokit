# Setup and recovery

## Scope and prerequisites

Tested on CachyOS/Arch with Niri and a systemd user graphical session. A full MATE
session normally uses X11: this layer-shell frontend has **not** been tested there
and requires Wayland. “MATE” here means the maintained backup Polkit agent.

Install the distribution's stock `quickshell`, `polkit`, `mate-polkit`, Python
3.12+, and Qt 6 Quick/QML, Controls, Shapes, and test tools. On the tested system
these are supplied by `qt6-base`, `qt6-declarative`, and their package dependencies.
Noctalia 5.2.1 is needed for automatic theme integration. Use Gaze's own
installation guide to install Gaze/PAM, configure the camera, download its models,
and enroll your face. These system dependencies are not built or installed by
this repository. Versions used are in [TESTED.md](TESTED.md).

## Authentication prerequisites

The UI displays PAM messages and submits responses; it cannot independently
recognize a face or enforce a confirmation after a PAM module already succeeds.
Enable `require_confirmation_elevation = true` in Gaze's existing `[auth]` table.
The exact Gaze confirmation messages are deliberately matched, not guessed.
Use `templates/gaze-auth.example.toml` as a merge example. Keep password fallback.
Gaze changes may require restarting `gazed` through your normal administration UI.

On the tested Arch system, `/etc/pam.d/polkit-1` has a **sequential**
`auth sufficient pam_gaze.so` before `auth include system-auth`; the complete
local example is `templates/polkit-1.arch.example`. This is not a portable
replacement for other distributions' PAM stacks. Review the original file, back
it up, retain a working administrative session, and merge only the appropriate
Gaze line. Follow Gaze's distribution-specific PAM guide in [references](../REFERENCES.md).
These files are never applied by `make install`. Use Polkit for administrative
commands on this setup (for example `pkexec systemctl restart gazed`), rather
than feeding a password to a script. This project does not alter `sudo` or SSH.

## User-local installation

1. `make preview` shows a mock without registering a Polkit agent. Try
   `python3 tools/manage.py preview --failure` for automatic password fallback,
   or `--state password`, `--state verified`, `--capture` for specific mock views.
2. `make test && make build` creates `dist/hello-polkit/`, containing runtime
   sources, assets, setup tools, documentation, tests, and a SHA-256 manifest.
3. `make install` copies the runtime to
   `$XDG_CONFIG_HOME/quickshell/hello-polkit/` (default `~/.config/...`), installs
   user units, and writes `noctalia/zz-hello-polkit.toml`. Existing runtime, units,
   and that fragment are backed up in `$XDG_STATE_HOME/hello-polkit/backups/`.
   It does not stop, start, enable, or reload a service. Use
   `python3 dist/hello-polkit/tools/manage.py install --mate /path/to/agent` if
   automatic MATE executable detection fails.
4. Review the generated Noctalia fragment. It disables the built-in Polkit agent
   and points its user palette template at `qml/palette.template.json`, generating
   `qml/palette.json`. Ensure Noctalia's *effective* `shell.polkit_agent` is false;
   persisted UI settings can override config fragments. Check with
   `noctalia config export full`. Reload/restart Noctalia if necessary, and ensure
   the user-template/app-theming feature is enabled. Do not run two session agents.
5. From a terminal in the Wayland desktop, `make activate`. It imports relevant
   session environment into the user manager, reloads units, starts Hello Polkit,
   and checks its registration before enabling login startup and disabling normal
   MATE startup. A registration failure switches back to MATE.
6. `pkexec --disable-internal-agent /usr/bin/true` tests a real prompt without
   changing system files. Check that face success waits for Allow/Enter, Cancel
   cancels, and password fallback works. An existing authorization cache or a
   custom policy may suppress the prompt.

The service is bound to `graphical-session.target`. Your compositor/session
manager must start that target and import the Wayland environment at login.
Do not add a second XDG/compositor autostart for either agent. If an old Noctalia
config already defines `theme.templates.user.hello_polkit`, consolidate it so
there is only one definition with the new `qml/` paths.

## Theme behavior

The generated palette is watched for changes. Python's standard library reads
Noctalia's resolved `shell.font_family` and `shell.corner_radius_scale`, and uses
Linux inotify to watch config/state directories, including atomic saves. Colors,
font family, and radii update without an agent restart. Radius bases are 6/9/12px
multiplied by the theme scale. Noctalia has no global UI font-size setting in this
version. Missing Noctalia/palette uses the committed Ayu Dark/default typography.
`NOCTALIA_CONFIG_HOME` and `NOCTALIA_STATE_HOME` name **base** directories, with
`noctalia/` appended; normal XDG directory variables are also respected.

## Recovery and backups

`make recover` disables/stops Hello Polkit and enables/starts MATE. No root access
is required. If you no longer have the checkout, run:

```sh
systemctl --user disable --now hello-polkit.service
systemctl --user enable --now mate-polkit.service
```

A crash, registration loss, or initial registration timeout exits nonzero and
triggers `OnFailure=mate-polkit.service`. An intentional successful stop does not
trigger it; use the recovery command when switching. The fallback is useful only
while its executable and user graphical session remain available.

Each backup has `restore-map.json` listing original destinations and their saved
files/directories. To revert the installed files, first recover to MATE, restore
the entries manually (a `null` saved value means the destination did not exist),
then run `systemctl --user daemon-reload`. Retain the backup until satisfied. PAM
and Gaze settings, if you changed them manually, require their own saved originals.
