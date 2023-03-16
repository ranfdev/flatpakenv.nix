# flatpakenv.nix
Build a .flatpak file using `nix` instead of `flatpak-builder`

<img 
  style="border-radius: 16px; margin: 0 auto;"
  src="https://user-images.githubusercontent.com/23294184/225986637-a9e01e7e-8425-4389-a77f-2b31147dac04.png"/>
<i>Image generated with midjourney. The snow represents nix transforming the flatpak packages/containers</i>

The function `flatpakenv.buildApp` prepares a script which can be run to export a .flatpak file.
This code is brittle, don't use it. I'm using it anyway.


