# TR-100 Machine Report
SKU: TR-100, filed under Technical Reports (TR).

A machine information used at [United States Graphics Company](https://x.com/usgraphics)

<img src="https://github.com/usgraphics/TR-100/assets/8161031/2a8412dd-09de-45ff-8dfb-e5c6b6f19212" width="500" />

‼️*** WARNING ***‼️

Alpha release, only compatible with Debian systems with ZFS root partition running as `root` user. This is not ready for public use *at all*. But you should totally try to use it. The worst that's going to happen is it'll destroy your system. Your help is appreciated in making this project production worthy.

Todo:
- [x] Run [Shellcheck](https://www.shellcheck.net/)
- [ ] Add basic variables that user can set to customize the system at the top. Encourage users to just edit the source code, even if they don't know what they are doing.
- [ ] Add guards for checking ZFS system, otherwise use `lsblk` or something native for disk info.
- [ ] Support multiple disks and `zpools`—may be just let the user add a section themselves for their specific system using a template.
- [ ] Modularize code so that subsystems can be turned off or on using args/flags.

Long term todo:
- [ ] Add support for non-Debian based systems. Primarily Ubuntu, RHEL/CentOS, Arch, FreeBSD and macOS.
- [ ] Allow support for multiple nics
- [ ] Ping test? Seems like a bad idea but useful to know the health of the tubes.

# Software Philosophy
Since it is a bash script, you've got the source code. Just modify that for your needs. No need for any abstractions, directly edit the code. No modules, no DSL, no config files, none of it. Single file for easy deployment. Only abstraction that's acceptable is variables at the top of the script to customize the system, but it should stay minimal. 

Problem with providing tools with a silver spoon is that you kill the creativity of the users. Remember MySpace? Let people customize the hell out of it and share it. Central theme as you'll see is this:

```
ENCOURAGE USERS TO DIRECTLY EDIT THE SOURCE
```

When you build a templating engine, a config file, a bunch of switches, etc; it adds 1) bloat 2) complexity 3) limits customization because by definition, customization template engine is going to be less featureful than the source code itself. So let the users just edit the source. Keep it well organized.

Another consideration is to avoid abstracting the source code at the expense of direct 1:1 readability. For e.g., the section "Machine Report" at the end of the bash script prints the output using `printf`—a whole bunch load of `printf` statements. There is no need to add loops or functions returning functions. What you see is roughly what will print. 1:1 mapping is important here for visual ID.

# Design Philosophy
Tabular, short, clear and concise. The tool's job is to inform the user of the current state of the system they are logging in or are operating. No emojis (except for the one used as a warning sign). No colors (as default, might add an option to add colors).

# Assumed Setup
This script is designed for us, for our internal use.

- AMD EPYC CPU
- Debian OS
- ZFS installed on root partition
- VMWare Hypervisor
- `root` user.

# Dependencies

- `lscpu`
- `bc` (For math in bash)

If your system is different, things might break. Look up the offending line and you can try to fix it for your specific system.

# Installation

Install `bc`: `apt install bc`.

For login sessions over ssh, reference the script `~/.machine_report.sh` in your `.bashrc` file. Make sure the script is executable by running `chmod +x ~/.machine_report.sh`.

Copy `machine_report.sh` from this repository and add it to `~/.machine_report.sh` ('.' for hidden file if you wish). Reference it in your `.bashrc` file as follows (example bashrc file):

```bash
# ~/.bashrc: executed by bash(1) for non-login shells.
# This is your .bashrc file.

# Machine Report     <---------- Add this line at the end of it
~/.machine_report.sh
```

# License
BSD 3 Clause License, Copyright © 2024, U.S. Graphics, LLC. See [`LICENSE`](https://github.com/usgraphics/machine-report-staging/blob/master/LICENSE) file for license information.
