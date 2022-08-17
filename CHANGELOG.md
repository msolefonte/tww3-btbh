# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - TBA

- Original work by Jadawin

## [2.0.0] - TBA

- Complete rework from scratch
- Added automatic support for DLC and mod races and factions
- Added support for AI to AI peace treaties
- Added player customization for different parameters
  - Thresholds for war duration, amount of battles, war exhaustion and minimum losses
  - Time between offers
- Added improved logging features for easier bug reports
- Modified war exhaustion formula to: `losses / (wins + losses) * 100 + duration - 5`
