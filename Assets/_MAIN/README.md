# Project Setup Guide

This document outlines the necessary packages and setup steps to ensure the project runs correctly.

## Required Unity Packages

Please ensure the following packages are installed via the Unity Package Manager (`Window > Package Manager`):

- **Input System**: For handling player input.
- **Universal RP (URP)**: The render pipeline used by the project.
- **Cinemachine**: Used for camera control (dependency of the 'Feel' asset).
- **Post Processing**: For visual effects (dependency of the 'Feel' asset).
- **TextMesh Pro**: For UI text rendering.
- **Animation 2D**: (Optional) Required for some demos included with the 'Feel' asset.

## Third-Party Assets

This project includes the following assets from the Asset Store or other sources. Make sure they are imported correctly.

- **Feel**: Located in `Assets/_EXTERNAL/Feel`. This asset is used for game feel effects.
- **Hyper Casual FX Vol.1**: Located in `Assets/_EXTERNAL/VFX_Klaus`. Used for visual effects.

## Render Pipeline Setup (URP)

If materials in the scene appear pink, it means they need to be upgraded to the Universal Render Pipeline.

### Step 1: Activate the Pipeline
1.  Go to `Edit > Project Settings > Graphics`.
2.  Find the `Scriptable Render Pipeline Settings` slot (it is likely "None").
3.  Assign your project's URP Asset to this slot.
4.  A popup might appear asking to confirm changing the pipeline. Click **Continue**.

### Step 2: Fix "Pink" Materials
1.  Go to `Window > Rendering > Render Pipeline Converter`.
2.  Select **Built-in to URP**.
3.  Check **Material Upgrade**.
4.  Click **Initialize and Convert**.

## Game-Specific Setup

- **Ground Layer**: The `HeroController` script on the player object needs a `Ground Layer` assigned. Make sure your platform prefabs are on a layer (e.g., "Ground") and that this layer is selected in the Hero Controller's inspector.