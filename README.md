# ColorGameTesting

ColorGameTesting is a cooperative color-matching prototype for **playtesting on Mac and iPhone**. Three players contribute colors to a shared bowl and try to match customer requests before time or lives run out.

The project provides configurable request difficulty, mixing modes, timers, and passing scores to support iterative testing of gameplay, teamwork, interface design, and request copywriting.

## Main Features

### Cooperative Color Mixing

- **RYB palette:** Red, Yellow, Blue, Black, and White.
- Each player receives two distinct colors. Different players may share a color.
- Each color input adds one unit to the shared bowl.
- Configurable color reassignment interval and optional target-color hints.
- **Manual Mix:** collect colors, select Mix, inspect the blended color and ingredient units, then Finish or Redo.
- **Auto Mix:** the bowl updates immediately after each input; select Apply to score it or Redo to clear it.
- Match scores use Lab color comparison with Delta E 2000 and a calibrated gameplay scoring curve.

### Single-Device and Three-Device Play

- Play together on one device or connect three devices over the same local network.
- In three-device play, the host manages settings and progression while each player contributes their assigned colors.
- Manual Mix requires all three players to vote Mix. Manual Redo/Finish and Auto Apply/Redo execute immediately after two matching votes.
- During mixing, tap the selected action again to cancel its vote. Players with a pending vote cannot add colors until they cancel; other players can continue contributing. Manual result-screen Redo/Finish votes remain final for that ballot.
- Connection recovery restores shared state and pending votes. Additional players and incompatible protocol versions are rejected.

### Endless Days

Complete a configurable number of successful customer requests to advance to the next Day. A failed match costs a life, and the next client receives a new request. The run continues until the Day timer expires or the mistake limit is reached.

Seven editable difficulty templates define the initial progression. From Day 8 onward, templates 5, 6, and 7 repeat.

| Difficulty template | Default request levels |
| --- | --- |
| 1 | 1, 1, 1 |
| 2 | 1, 1, 2 |
| 3 | 1, 2, 2 |
| 4 | 1, 2, 3 |
| 5 | 2, 2, 3 |
| 6 | 2, 3, 3 |
| 7 | 3, 3, 3 |

Here, a **client** is a customer request, not a connected player device.

### Configurable Playtest Settings

| Setting | Default | Behavior |
| --- | --- | --- |
| Mixing mode | Manual Mix | Choose Manual Mix or Auto Mix. |
| Daily target | 3 successful clients | Edit the target and request levels for each difficulty template. |
| Passing score | 70% | A score at or above the configured threshold passes. |
| Timer mode | Day Timer | Choose one timer mode for the run. |
| Day duration | 10 minutes | An unfinished daily target at expiry ends the run. |
| Client duration | 3 minutes | Expiry costs one life and moves to a new request if the run remains active. |
| Mistake limit | 3 per Day | The third mistake ends the run; unlimited mistakes are also available. |

Lives reset when a new Day begins. Redo clears the mix without counting as a mistake or restoring time. After Game Over, the host can restart from Day 1 or return to the settings lobby.

### Editable Request Pool

- Requests are organized into three difficulty levels.
- Add custom request text, a six-digit hexadecimal target color, and a difficulty level.
- Edit built-in or custom request text, target color, and difficulty; built-in edits are saved as local overrides.
- Delete built-in or custom requests from settings.
- Random selection uses a shuffled queue for each level: requests do not repeat until that level's pool has been exhausted.
- Custom requests and built-in deletion preferences persist locally on the device. In network play, the host's request pool supplies the shared requests.
- Starting a run requires available requests for every configured difficulty level.

### Shared Mac and iPhone Interface

- Compact gameplay, color-breakdown, and score screens with consistent bowl placement.
- Highlighted request cards, remaining-life hearts, timer, and Day/client progress.
- Centered new-client notices with a dismiss button and full request text; long requests can be reopened through See more.
- Optional hints appear in both the request card and notice.
- Clear PASS or MISS feedback, with the numerical match score as supporting information.
- Landscape iPhone layout and Mac keyboard controls.

## Installation and Running

### Requirements

- A Mac with full Xcode installed. The project has been built with **Xcode 27.0**.
- **macOS 27.0 or later** for the Mac application, as configured in the project.
- **iOS 17.0 or later** for the iPhone application. The iOS target supports iPhone in landscape orientation.
- A development signing team when installing on a physical iPhone.

The application has no third-party runtime dependencies to install.

### Get the Project

```bash
git clone https://github.com/denywa/ColorTesting.git
cd ColorTesting
open ColorGameTesting2.xcodeproj
```

### Run on Mac

1. Select the **ColorGameTesting** scheme in Xcode.
2. Select a compatible Mac destination.
3. Run the application with **Command-R**.
4. Choose single-device play or create/join a three-device session.

In single-device Mac play, the color keys are:

| Player | Color controls |
| --- | --- |
| Player 1 | Q / W |
| Player 2 | B / N |
| Player 3 | O / P |

### Run on iPhone

1. Select the **ColorGameTestingiOS** scheme.
2. Select an iPhone Simulator or a connected iPhone.
3. For a physical device, select your development team in **Signing & Capabilities** and complete the device's development setup.
4. Run with **Command-R** and use the landscape touch controls.

### Start a Three-Device Playtest

1. Install matching application builds on all three devices and connect them to the same Wi-Fi network.
2. On the host, choose **Three Devices** and **Create Session**.
3. On the other devices, choose **Find Sessions** and join the host's session.
4. Allow local-network access when prompted.
5. Once all three players are connected, configure the run on the host and start.

Sessions use Bonjour discovery and local TCP connections. No remote server or account is required. Returning to the lobby preserves the connected session; guests can leave individually.

## Folder Structure

```text
ColorGameTesting/
├── ColorGameTesting/             # Shared application source
│   ├── ColorGameTestingApp.swift # App entry point
│   ├── ContentView.swift         # Screen routing
│   ├── GameViewModel.swift       # Gameplay orchestration
│   ├── GameModels.swift          # Shared models and controls
│   ├── GameState.swift           # Observable game state
│   ├── EndlessRun.swift          # Day progression and timer budgets
│   ├── ColorData.swift           # Built-in colors and requests
│   ├── ColorMixer.swift          # RYB mixing
│   ├── ColorConverter.swift      # Color-space conversion
│   ├── ScoreCalculator.swift     # Match scoring
│   ├── CustomRequestStore.swift  # Local request persistence
│   ├── KeyRouter.swift           # Mac keyboard input
│   ├── LocalPlay/                # Discovery, transport, voting, and snapshots
│   ├── Views/                    # Settings, gameplay, results, and shared UI
│   └── Assets.xcassets/          # Application assets
├── ColorGameTestingTests/        # XCTest coverage
├── ColorGameTesting2.xcodeproj/  # Mac and iPhone targets and schemes
├── Config/                      # Local-network configuration
├── .kiro/                       # Project steering and feature specifications
├── .agents/skills/              # Local development-assistant skills
└── AGENTS.md                    # Development workflow guidance
```

## Technologies Used

| Technology | Purpose |
| --- | --- |
| Swift | Application and game logic; project language mode is Swift 5. |
| SwiftUI | Shared, adaptive Mac and iPhone interface. |
| Observation | Observable state and view bindings. |
| Foundation | Serialization, timers, identifiers, and local preferences. |
| Network.framework and Bonjour | Local session discovery and TCP communication. |
| AppKit | Mac keyboard-event handling. |
| SIMD, Lab, and Delta E 2000 | Color calculations and calibrated match scoring. |
| XCTest | Unit and integration testing. |
| Xcode | Builds, signing, simulators, and platform targets. |

## Verification and Playtesting

Run the Mac test suite with a compatible Xcode toolchain and Mac destination:

```bash
xcodebuild \
  -project ColorGameTesting2.xcodeproj \
  -scheme ColorGameTesting \
  -configuration Debug \
  -destination 'platform=macOS' \
  test CODE_SIGNING_ALLOWED=NO
```

Build the iPhone Simulator target:

```bash
xcodebuild \
  -project ColorGameTesting2.xcodeproj \
  -scheme ColorGameTestingiOS \
  -configuration Debug \
  -destination 'generic/platform=iOS Simulator' \
  build CODE_SIGNING_ALLOWED=NO
```

Physical-device touch behavior, voting, disconnect/reconnect recovery, and local-network permissions should also be checked during playtests.

This prototype does not persist run progress or collect playtest analytics. Record observations separately. Its color model and score are calibrated gameplay feedback rather than a physical pigment simulation.
