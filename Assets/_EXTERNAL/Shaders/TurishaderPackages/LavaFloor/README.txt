# Stylized Lava & Magma Shader - Parameter Reference

This document explains the function of each exposed parameter in the shader inspector.

## 🔷 Surface Inputs
### ProjectionMode
Sets whether the lava pattern is projected in World or Object space. Use World for seamless large surfaces.

### OverallScale
Controls the overall scale of the lava and crust pattern. Higher values enlarge the entire effect.

### TurbulenceSpeed
Adjusts the internal turbulence animation speed, giving the lava a more agitated or dynamic look.

### ScrollSpeed
Sets the direction and speed of the UV scrolling (X, Y, Z, W), simulating directional lava flow.

## 🔷 Lava
### LavaColor
HDR color of the molten lava. Affects the general brightness and tone of the lava.

### Lava smoothness
Determines how reflective or matte the lava surface appears. Lower values make it look rougher.

### LavaParallaxDepth
Controls the depth of the parallax effect within the lava to create a sense of internal volume.

### LavaLevel
Defines the minimum visible level of the lava. Controls how much lava is revealed beneath the crust.

## 🔷 Crust
### CrustLevel
Sets the threshold where the solid crust begins to appear. Affects the distribution of solid vs molten areas.

### CrustFadeDistance
Controls how smoothly the crust fades where it contacts other geometry, based on the depth texture.

### CrustColor
HDR color of the crust (solidified lava). Typically a dark tone like black or deep purple.

### Crust smoothness
Determines the reflectivity of the crust surface. Use it to create dry, rocky or glossy effects.

## 🔷 Vertex wave
### Lava wave offset
Controls the amplitude of the vertex displacement wave.

### Lava wave tiling
Controls how often the wave pattern repeats across the surface.

### Wave scroll speed
Controls the speed and direction of the wave movement (X, Y).

---
For any questions, feedback or support, feel free to contact: **turishader@gmail.com**
