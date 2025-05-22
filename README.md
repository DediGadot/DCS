# DCS

This repository contains Lua scripts for scoring in DCS World and a Python tool for parsing TacView logs.

## tacview_stats.py

`tacview_stats.py` reads TacView `.acmi` files and prints sortie and kill statistics per pilot and formation.

### Usage

```bash
python tacview_stats.py <logfile>
```

Both plain text and zipped `.acmi` logs are supported. The script counts sorties, kills (air, ground, ship), refuels, CSAR pickups and friendly fire incidents.

### TacView Log Format

A TacView log is a comma separated text file where each line represents an object state or event. Lines starting with `#` are comments. Object lines contain fields like `Pilot`, `Group`, `Type` and `Coalition` for a specific object identifier. Event lines include an `Event` field such as `TakeOff`, `Kill` or `Refuel` referencing the object identifiers involved. The parser uses this information to build the statistics table.
