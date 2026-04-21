# Weather Dashboard

[![Live Demo](https://img.shields.io/badge/Live-Demo-6366f1?style=for-the-badge&logo=github&logoColor=white)](https://caasiyatnilab-sketch.github.io/weather-app/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg?style=flat-square)](LICENSE)

Live weather dashboard with current conditions, 5-day forecast, and city search. No API key required.

![Weather Dashboard Screenshot](https://img.shields.io/badge/Status-Live-22c55e?style=flat-square)

## Features

- **Current weather** -- temperature, humidity, wind speed, "feels like"
- **5-day forecast** -- daily breakdown with icons and temps
- **City search** -- look up weather for any city worldwide
- **Responsive** -- clean layout on any screen size
- **No API key** -- uses [wttr.in](https://wttr.in) free weather service

## Quick Start

```bash
git clone https://github.com/caasiyatnilab-sketch/weather-app.git
cd weather-app
open index.html
```

That's it. No dependencies, no build step, no API key.

## Tech Stack

| Component | Technology |
|-----------|-----------|
| Frontend | HTML5, CSS3, vanilla JavaScript |
| API | [wttr.in](https://wttr.in) (free, no key) |
| Fonts | Inter (Google Fonts) |
| Design | Minimal, light theme with indigo accents |

## API

This app uses **wttr.in** -- a free weather service that requires no registration or API key. It returns JSON weather data for any city:

```
https://wttr.in/London?format=j1
```

## Project Structure

```
weather-app/
  index.html    # Single-page app (HTML + CSS + JS inline)
  LICENSE        # MIT License
  README.md     # This file
```

## Live Demo

**[caasiyatnilab-sketch.github.io/weather-app](https://caasiyatnilab-sketch.github.io/weather-app/)**

## License

MIT -- see [LICENSE](LICENSE) for details.
