# Genesis

I've been reinstalling my box a lot lately. So this is my personal Windows 10
setup script for making initial configuration easier. I think it would save
me about 30 minutes per setup; if I can automate software installs, even much
more. I spent about 2 hours or so on this script in total but learned a great
deal about PowerShell in return, which was a bonus.

You might I ask why I didn't use something like Microsoft Configuration Manager
for that. It looked very complicated for my purposes and requires a client running
on the machine which is absolutely unnecessary for my personal use. I just needed
a simple automation.

## Running Genesis

First, examine the contents of `SampleConfig.psd1` and edit as necessary. Don't
forget that your changes will be permanent and irreversible (I hope to fix that
in the future). Then run the command below on a PowerShell prompt:

    .\Setup SampleConfig.psd1

It will make necessary changes on your system and install Chocolatey and required
packages as needed. Genesis changes system settings, it never removes a file, or
uninstalls an app. So the worst can be weird settings and some additional unwanted
software installed on your computer. You should still be careful running tools like
these though.

## Roadmap

I don't want to spend too much time on this project, that's one of the
reasons why I used PowerShell as it was the simplest way to do it. I'd
like to add some features though:

* [X] Add checks for non-Store apps (chocolatey integration maybe?) although
  I'm not very fond of Chocolatey.
* [X] Get config file as a parameter
* [ ] Switch to a more portable configuration format
* [ ] Ability to generate config files from existing state of a system
* [ ] Support PowerShell Confirm/WhatIf system
* [ ] Easier installation using PowerShellGet, e.g. `Install-Module Genesis`
* [ ] Modularize configuration handling better

## License

MIT License. See LICENSE file for details.
