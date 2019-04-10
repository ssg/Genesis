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

# Running Genesis

Just type `.\Setup -Force` on a PowerShell prompt. Beware that it would change your system configuration permanently.

# Roadmap

I don't want to spend too much time on this project, that's one of the
reasons why I used PowerShell as it was the simplest way to do it. I'd
appreciate some features though:

- Add checks for non-Store apps (chocolatey integration maybe?) although
  I'm not very fond of Chocolatey.

# License

MIT License. See LICENSE file for details.