# Game of Life in Zig

[![zig build test](https://github.com/insolor/game-of-life.zig/actions/workflows/zig-build-test.yml/badge.svg)](https://github.com/insolor/game-of-life.zig/actions/workflows/zig-build-test.yml)

> [!WARNING] 
> WORK IN PROGRESS

This is an implementation of [Conway's Game of Life](https://en.wikipedia.org/wiki/Conway%27s_Game_of_Life) in [Zig](https://ziglang.org/) programming language with infinite field.

The field is represented as a sparse 2D array of blocks.

Started as a reimplementation of a prototype of the same idea in python: [insolor/game-of-life](https://github.com/insolor/game-of-life)

Plans:

- [x] Infinite field
- [x] Engine (calculate next field state)
- [ ] GUI
- [ ] Mouse and keyboard control
- Optimizations:
  - Parallelization?
  - Reuse memory instead of destroying and creating of fields?
- Some cool stuff:
  - Fish-eye view?
