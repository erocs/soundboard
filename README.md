# Soundboard

A configurable soundboard application built with Godot 4.6. Assign WAV files to buttons, organize them into folders, and play them with a click.

## Features

- **Sound buttons** — assign WAV files and custom labels, colors, and images to each button
- **Folder groups** — organize buttons into expandable folder panels
- **Audio capture** — record audio directly from your microphone
- **Audio editor** — trim and edit recorded or imported audio
- **File manager** — browse, rename, and delete imported sounds and images

## Requirements

- [Godot 4.6](https://godotengine.org/) (Forward Plus renderer)

## Getting Started

1. Clone this repository.
2. Open the project in Godot 4.6 (`project.godot`).
3. Run the project (`F5`).
4. Right-click any button to assign a WAV file, label, color, or image.

## Project Structure

```
scripts/
  data/         # ButtonConfig, ConfigManager (load/save board.json)
  soundboard/   # SoundButton, Soundboard container
  main.gd       # Root controller, context menu, dialogs
scenes/
  soundboard/   # sound_button.tscn, soundboard.tscn
sounds/         # Bundled sound assets
```

Configuration is stored in `user://config/board.json`; imported sounds and images are copied to `user://sounds/` and `user://images/`. On Windows, `user://` resolves to `%APPDATA%\Godot\app_userdata\Soundboard\`.

## License

MIT — see [LICENSE.md](LICENSE.md).
