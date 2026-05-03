# ECE-554 Project - Genetic Algorithm-GOAP Game AI
**Date:** April 5, 2026

This project was completed for ECE-554 at the University of Michigan.

**Live demo:** https://ece554.nqazi.com

## Project Overview
This project presents the implementation of a hybrid artificial intelligence architecture that integrates Goal-Oriented Action Planning (GOAP) with a genetic learning algorithm to enable adaptive, experience-driven decision making. Traditional GOAP systems are widely used in real-time applications such as video games due to their efficiency and transparency; however, they typically rely on static or random goal-selection mechanisms, limiting their ability to improve over time. To address this limitation, this work replaces fixed goal selection with a genetically optimized, probability-weighted strategy that evolves based on agent performance.

The system is implemented within a real-time cooperative wildfire suppression simulation, where multiple drone agents operate on a grid-based environment. Each agent uses GOAP to generate action plans while selecting high-level goals (such as targeting specific fires or assisting other agents) based on evolving genetic parameters. After each simulation round, agents are evaluated using performance metrics including fires extinguished, forest area preserved, and response efficiency. Lower-performing agents are removed, and new agents are generated through crossover and mutation of successful strategies, enabling continuous improvement across generations.

## Results: GOAP vs. GOAP + GA
Comparing the baseline GOAP-only configuration against the hybrid GOAP + Genetic Algorithm configuration, the GA layer produced clear gains in both performance and consistency:

- On average, rounds were completed in **12.54% less time**, with **9.27% more trees saved**.
- Beyond raw efficiency, we noted a significant increase in consistency. Variability decreased by **8.6%** for completion time and roughly **24.5%** for both trees saved and round success rates.

## Installing Godot 4 Engine
Godot 4 is a free, open-source, cross-platform game engine that runs on Windows, macOS, and Linux.

### Windows
1. Go to https://godotengine.org/download  
2. Download the Windows 64-bit version  
3. Extract the .zip file  
4. Run the executable  (.exe)  

Godot does not require installation; just run the executable after extraction.

### macOS
1. Download the macOS version from the Godot website  
2. Open the downloaded .dmg or .zip file  
3. Drag the Godot app into the Applications folder  
4. Launch it from Applications  

### Linux
1. Download the Linux version from the Godot website  
2. Extract the archive:
    tar -xzf Godot_v4.x.x-stable_linux_x86_64.tar.gz

3. Make it executable:
    chmod +x Godot_v4.x.x-stable_linux_x86_64

4. Run:
    ./Godot_v4.x.x-stable_linux_x86_64

## Cloning and Running the Project
### 1. Clone the Repository
    git clone https://github.com/SgtP4in/ECE-554_Project.git
    cd ECE-554_Project

### 2. Open Project in Godot 4
1. Launch Godot 4
2. Click Import in the Project Manager
3. Navigate to the cloned repository folder
4. Select the project.godot file
5. Click Import & Edit

### 3. Run the Project
- Click the Play button in the top-right corner  

This will launch the main scene and run the project.

## Project Structure in Godot
### Scenes (Levels)
- Located in the FileSystem panel
- Stored as .tscn files
- Represent levels, menus, or game states

### Nodes / Objects / Actors
- Found in the Scene panel (top-left)
- Organized in a hierarchical structure
- Examples:
  - Player
  - Enemies
  - UI elements
  - Environment objects

### Scripts (Source Code)
- Stored as .gd files in the FileSystem panel
- Attached to nodes to define behavior
- Edited using Godot’s built-in script editor

### Assets
- Includes textures, audio, models, and other resources
- Accessible through the FileSystem panel

### Inspector (Properties Panel)
- Located on the right side of the editor
- Used to modify node properties (position, physics, visuals, etc)

### Output / Debug Console
- Located at the bottom of the editor
- Displays logs, errors, and debugging information during runtime

## Notes
- Godot projects are portable and require no additional installation beyond the engine executable  
- Ensure you are using Godot 4.x, as earlier versions may not be compatible

## Future Work
A natural next step is to compare this GOAP + Genetic Algorithm approach against a Reinforcement Learning baseline, evaluating both performance and consistency on the same wildfire suppression task.
