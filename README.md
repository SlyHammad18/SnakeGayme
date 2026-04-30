# Snake Game (MASM32)

![Windows](https://img.shields.io/badge/Windows-10%2B-blue?logo=windows&logoColor=white)
![MASM32](https://img.shields.io/badge/MASM32-Assembly-orange)
![Audio](https://img.shields.io/badge/Audio-MCI-green)

A classic Snake game written in x86 Assembly using MASM32 and Win32 APIs. The game includes two play modes, sound effects, background music, and a main menu with a snake color selector.

## Features

- Classic and Boundaried modes
- Menu-driven UI with color presets
- Score tracking and saved high scores
- MP3 background music and sound effects

## Controls

- Arrow keys: Move the snake
- Enter: Select a menu option
- Left/Right (in menu): Change snake color

## Build

1. Install MASM32 to C:\masm32 (or update the path inside [make.bat](make.bat)).
2. Run this from the project root:

```
make.bat
```

Build output includes [snake.exe](snake.exe) and [snake.obj](snake.obj).

## Run

```
snake.exe
```

Make sure [Music/](Music/) contains the MP3 files referenced in [snake.asm](snake.asm).

## Project Files

- [snake.asm](snake.asm) - main game code
- [make.bat](make.bat) - build script
- [Music/](Music/) - background music and SFX
- [scores.dat](scores.dat) - saved high scores (created at runtime)
