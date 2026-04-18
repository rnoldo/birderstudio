# Kestrel — Product Plan v0.1

> Cull, polish, create — one app, everything you need.

## Vision

Kestrel is the all-in-one Mac desktop app for birders. It replaces a fragmented workflow of 4-5 tools with a single, blazing-fast native application that brings culling, polishing, creating, and sharing together. No forced sequence, no rigid pipeline — whatever you need to do, it's right there.

Target: 10x better than anything birders currently use. Not by piling on features, but by doing three things at once: every feature is exceptionally well-crafted on its own, features connect seamlessly into one flow, and both beginners and power users feel at home. Like Figma, like Mac, like iPhone — simple things are obvious, complex things are possible and elegant.

## Target Users

**Primary:** Active birders who shoot regularly (weekly+), accumulate thousands of photos per outing, and share on social media or birding communities. They own decent gear but are not professional photo editors — they want great results without Lightroom complexity.

**Secondary:** Bird club organizers, nature educators, citizen science contributors who need to process and present bird imagery efficiently.

## Design Principles

1. **Every feature, exceptionally crafted** — Not "good enough", but polished to delight. Crop isn't just crop — it's bird-aware crop. Export isn't just export — it's one-tap masterpiece.
2. **One app, everything** — Culling, polishing, creating all live in one place. No forced sequence, no rigid workflow. You can start from culling, or jump straight to making a postcard from an old photo. Like Notion is to document work, we are to bird imagery work.
3. **Beginners welcome, experts at home** — Like Figma and iPhone: obvious on first launch, but endlessly deep. Simple operations are one-click; complex operations are possible and elegant.
4. **Bird-first intelligence** — Every feature knows there's a bird in the frame. Auto-crop, auto-label, auto-enhance all center on the subject.
5. **Speed is a feature** — Sub-second response for every interaction. No spinners, no waiting.
6. **Beauty as standard** — Every output looks good by default. Templates, presets, and exports are designed to a high standard out of the box.

---

## Product References: Five Benchmarks, Five Laws

We don't reinvent the wheel. Five products that achieved excellence in their domains — we take one key lesson from each.

### Pixelmator Pro — "ML is invisible magic, not a feature to showcase"

Pixelmator Pro's genius isn't that it uses ML — it's that you can't tell it uses ML. You click "Auto White Balance" and it's correct. You click "Super Resolution" and the image is sharp. No parameters, no progress bars, no "AI is processing" banners. ML is the means, not the selling point.

Many products make the mistake of flaunting AI as a feature — "Look, we used AI!" Pixelmator never does this. Its attitude: you don't need to know what's happening under the hood. The result is what matters.

**How we apply this:** Our bird detection, quality scoring, and species identification should be invisible to users. They should just see: photos automatically sorted by quality, species names automatically labeled, crops automatically centered on the bird. If users need to understand ML to use our product well, we've failed.

### Darkroom — "One interface serves both beginners and experts"

Darkroom got one thing right: the same interface serves two audiences. Beginners see a few sliders — brightness, contrast, saturation, just slide left or right. Experts see color curves, HSL, selective adjustments. These two layers aren't toggled in settings as "Simple Mode / Pro Mode" — they're naturally nested. Basic adjustments are right there; tap "More" to reveal the advanced ones.

Another highlight: batch editing. Adjust one photo's parameters, one-click apply to the entire group. This is critical for us — birders shoot hundreds of photos in the same scene with identical lighting; they shouldn't have to edit each one individually.

**How we apply this:** The Polish stage UI should not have two modes — it should be one progressive interface. Show the 5 most common adjustments by default (crop, exposure, white balance, sharpening, saturation); deeper or further clicks reveal noise reduction, curves, selective edits. Batch application within scenes must be a first-class citizen — edit one, the whole scene follows.

### Linear — "So fast you forget it's software"

Linear's core insight: software speed directly affects thinking speed. When a tool is fast enough, you stop "operating the tool" and start "thinking about the problem."

What Linear does: all operations are instant with no loading states; keyboard shortcuts cover everything so hands never leave the keyboard; `Cmd+K` universal search finds anything; animations are ultra-short (100-150ms), providing feedback without wasting time. And something rarely mentioned: Linear's defaults are excellent. Creating an issue doesn't require filling 12 fields. Title, Enter, done.

**How we apply this:** The Cull stage must achieve Linear-level speed. Birders culling 2,000 photos — if each takes 0.5 seconds to load the next, that's 1,000 seconds of waiting. Unacceptable. We need: instant switching on keypress, preloaded next images, silky gestures and keyboard response. `Cmd+K` global search should exist too — search species, dates, locations, projects, all from one entry point.

### Figma — "Features are discovered, not taught"

Figma's greatest strength isn't feature count — it's learning curve design. First time in Figma, you can draw a rectangle and type text. A month later you discover Auto Layout. Three months later, Components. Six months later, Variables. Each layer appears naturally when you need it, not force-fed through a 30-minute onboarding tutorial.

The philosophy behind this: interface information density should scale with user proficiency. Beginners see a clean interface because advanced features are tucked away. Veterans see a rich interface because they know where to look.

Another insight: Figma has almost no modal dialogs. All operations complete in-place on the canvas. Context menus, property panels, layer lists — all extensions of the canvas, not separate dialog boxes.

**How we apply this:** Two things. First, no onboarding tutorials. If it needs a tutorial, the design has failed. Features should surface contextually — when a user selects a bird photo, "Smart Crop" appears right there, not buried in a menu. Second, avoid modals. Export settings, watermark settings, annotation editing should all happen in-place within the main interface, never breaking immersion with popup windows.

### Loom — "Turn ten steps into one"

Before Loom, sharing a screen recording meant: open QuickTime -> select recording area -> record -> stop -> save file -> compress -> upload somewhere -> copy link -> send. Ten steps. After Loom: click to start, click to stop, link is in your clipboard. Two steps.

The insight: most users don't need control over intermediate steps. They don't need to pick an encoding format, choose a resolution, or manually upload. They just want the result.

**How we apply this:** This directly guides our "Bird Portrait" one-tap preset and "Social Ready" export. Currently, a birder posting a photo to social media needs: open editor -> crop -> adjust exposure -> adjust white balance -> sharpen -> add watermark -> export -> pick format -> pick quality -> upload. We should achieve: select photo -> tap "Share" -> done. Cropping, enhancement, watermarking, format conversion all happen automatically with smart defaults. Of course, every step can be manually adjusted, but the default path is one tap.

### Quick Reference

| Learn from | Core law | Applied to our product |
|---|---|---|
| Pixelmator Pro | ML is invisible magic, not a showcased feature | Bird detection, scoring, ID all happen invisibly |
| Darkroom | One interface for beginners and experts, batch editing | Progressive editing UI + scene-level batch apply |
| Linear | Speed is thinking, defaults must be good | Culling must be instant, all operations have good defaults |
| Figma | Features discovered not taught, no modals | No tutorials, contextual feature surfacing, everything in-place |
| Loom | Turn ten steps into one | "One-tap export": select photo, tap share, done |

---

## Architecture

### Tech Stack

| Layer | Technology | Why |
|---|---|---|
| UI | SwiftUI | Native Mac feel, smooth animations, accessibility built-in |
| Image Processing | Core Image + Metal | GPU-accelerated filters, real-time preview |
| ML / Bird Detection | Core ML | Small model size, on-device inference, hardware acceleration |
| Storage | SwiftData / SQLite | Fast local database for photo metadata, tags, projects |
| File Handling | Uniform Type Identifiers | Native RAW support (CR2, CR3, NEF, ARW, DNG) via ImageIO |
| Export | PDFKit + Core Graphics | Print-ready output for merchandise templates |
| AI Generation | Stable Diffusion (Core ML) / External API | Style transfer, illustration generation |

### Model Migration

Existing PyTorch models (Mask R-CNN for bird detection, quality classifier) will be converted to Core ML format using `coremltools`. This reduces model size significantly and enables Neural Engine acceleration on Apple Silicon.

---

## The Three Stages

## Stage 1: Cull — "From chaos to clarity"

The smart triage system. Handles the painful first step of turning 2,000 raw shots into 50 keepers.

### Core Features

| Feature | Description | Priority |
|---|---|---|
| Auto-Import | Watch folder or SD card mount, auto-ingest | P0 |
| Bird Detection | Locate bird(s) in frame using Core ML | P0 |
| Quality Scoring | Score sharpness, noise, motion blur, exposure | P0 |
| Scene Grouping | Cluster burst sequences by timestamp + visual similarity | P0 |
| Species ID | Auto-classify species, display common + scientific name | P0 |
| Quick Cull UI | Swipe/keyboard-driven accept/reject, show best-in-group first | P0 |
| Multi-Subject | Handle frames with multiple birds, score each independently | P1 |
| RAW Support | CR2, CR3, NEF, ARW, DNG, RAF native decoding | P0 |
| Smart Filters | Filter by species, quality tier, date, camera body, lens | P1 |
| Cull Statistics | "You kept 47 of 2,341 photos. 12 species detected." | P2 |

### UX Flow

```
SD Card / Folder
    |
    v
[Import] --> [Detect Birds] --> [Score Quality] --> [Group Scenes]
    |
    v
[Cull View: scene-by-scene, best first, swipe to accept/reject]
    |
    v
"Accepted" pool --> flows into Stage 2
```

---

## Stage 2: Polish — "From keeper to masterpiece"

A light editor purpose-built for bird photography. Not Lightroom — faster, simpler, and smarter about birds.

### Core Features

| Feature | Description | Priority |
|---|---|---|
| Smart Crop | Auto-detect bird, suggest optimal crop with rule-of-thirds | P0 |
| Exposure / Brightness | Basic exposure correction with highlight protection | P0 |
| White Balance | Presets (daylight, overcast, shade, golden hour) + manual | P0 |
| Sharpening | Feather-detail aware sharpening (sharpen subject, not background) | P0 |
| Noise Reduction | ML-based denoising, preserve feather detail | P1 |
| Saturation / Vibrance | Subtle plumage color enhancement | P1 |
| Background Blur | Deepen background bokeh, isolate subject | P1 |
| Eye Brighten | Auto-detect and add catch-light to bird's eye | P1 |
| Subject Vignette | Darken edges while preserving bird exposure | P1 |
| Background Cleanup | Remove/diminish distracting branches, wires | P2 |
| Perch Cleanup | Light clone/heal for small distractions near bird | P2 |

### One-Tap Presets

The killer feature: intelligent presets that understand the bird is the subject.

| Preset | What It Does |
|---|---|
| Bird Portrait | Auto-crop + sharpen feathers + blur background + brighten eye + vignette |
| Field Guide | Tight crop, neutral white balance, flat lighting, full body visible |
| Drama | High contrast, deep shadows, warm highlights, strong vignette |
| Clean & Bright | Lift shadows, cool tones, minimal processing, editorial feel |
| Social Ready | Platform-optimized crop + subtle enhance + watermark |

### Annotation & Overlay

| Feature | Description | Priority |
|---|---|---|
| Species Label | Auto-overlay common name / scientific name / family | P0 |
| Location & Date | GPS or manual location + date stamp | P1 |
| EXIF Display | Camera body, lens, focal length, ISO, shutter speed | P1 |
| Field Mark Arrows | Point-and-click arrows/circles to highlight ID features | P1 |
| Custom Text | Free-form text overlay with typography options | P2 |

### Watermark System

| Feature | Description | Priority |
|---|---|---|
| Text Watermark | Name / handle / copyright with opacity and position control | P0 |
| Image Watermark | Import logo/signature as watermark | P0 |
| Smart Placement | Auto-avoid placing watermark over the bird | P1 |
| Batch Apply | Apply same watermark to entire export set | P0 |

### Export

| Feature | Description | Priority |
|---|---|---|
| Platform Presets | Instagram (1:1, 4:5), Twitter/X (16:9), WeChat Moments, Facebook | P0 |
| Batch Export | Export all accepted photos with consistent settings | P0 |
| Format Options | JPEG (quality slider), PNG, HEIF, TIFF | P0 |
| Resolution Control | Original, 2x downscale, custom dimension | P1 |

---

## Stage 3: Create — "From photo to product"

Turn bird imagery into tangible and digital products. Sources are not limited to user's own photos — can use personal illustrations, royalty-free images, or AI-generated artwork.

### Image Sources

| Source | Description |
|---|---|
| My Photos | Bird photos from Stage 1/2 |
| My Artwork | Import hand-drawn illustrations, paintings, digital art |
| AI Generate | Generate bird illustrations from text prompt or photo reference |
| Free Library | Curated royalty-free bird imagery (Macaulay Library, Unsplash, etc.) |

### AI Generation

| Feature | Description | Priority |
|---|---|---|
| Photo to Illustration | Convert bird photo to watercolor / ink / woodcut / vector style | P1 |
| Text to Bird Art | "A northern cardinal on a snowy branch, watercolor style" | P1 |
| Style Presets | Field guide, vintage naturalist, modern minimal, Japanese brush | P1 |
| Variation Generation | Generate multiple variations from one source image | P2 |

### Product Templates

#### Print Products

| Product | Template | Priority |
|---|---|---|
| Postcards | 4x6, 5x7 with bleed, back design options | P1 |
| Greeting Cards | Folded, with interior text layout | P1 |
| Monthly Calendar | 12-month layout, species per month, date grid | P1 |
| Art Prints | 8x10, 11x14, 16x20 with mat/frame preview | P1 |
| Sticker Sheet | Auto-arrange multiple birds on A4/Letter sheet | P2 |
| Poster | Life List grid (best shot per species), Big Year summary | P1 |

#### Wearables & Objects

| Product | Template | Priority |
|---|---|---|
| Hat / Cap | Embroidery-style preview, front patch mockup | P2 |
| T-Shirt | Front/back print placement preview | P2 |
| Tote Bag | Print area preview | P2 |
| Mug | Wrap-around print preview | P2 |
| Phone Case | Device-specific templates | P2 |
| Pin / Badge | Circular/custom shape crop | P2 |

#### Digital Products

| Product | Template | Priority |
|---|---|---|
| Personal Field Guide | Species pages: photo + name + notes + range map layout | P1 |
| Photo Book | Auto-layout by species / region / date with text blocks | P2 |
| Social Collage | 2x2, 3x3, comparison grids for ID posts | P0 |
| Species Comparison | Side-by-side: male/female, breeding/non-breeding, juvenile/adult | P1 |
| eBird Export | Photos with metadata formatted for eBird upload | P2 |

### Output Formats

| Output | Description | Priority |
|---|---|---|
| Print-Ready PDF | CMYK, proper bleed, crop marks, 300 DPI | P0 |
| PNG / JPEG | High-res digital export | P0 |
| POD Integration | Direct export to Redbubble / Zazzle / Printful API | P2 |
| Share Sheet | macOS native share to social media, AirDrop, email | P0 |

---

## Cross-Cutting Features

### Data & Organization

| Feature | Description | Priority |
|---|---|---|
| Photo Library | Persistent, searchable library of all processed photos | P0 |
| Smart Albums | Auto-generated: by species, by date, by location, by quality tier | P1 |
| Tags & Favorites | Manual tagging and starring | P1 |
| Life List | Auto-maintained species checklist from your photo library | P1 |
| Project System | Group photos + edits + products into "outings" or "projects" | P1 |

### Performance Targets

| Metric | Target |
|---|---|
| App launch to interactive | < 1 second |
| Photo thumbnail generation | < 100ms per image |
| Full RAW decode + display | < 500ms |
| ML inference (bird detect + species) | < 200ms per image on Apple Silicon |
| Filter/edit preview | Real-time (60fps) |
| Batch process 1000 photos | < 5 minutes |
| App bundle size | < 200MB (excluding optional AI models) |

### Platform Integration

| Feature | Description | Priority |
|---|---|---|
| Spotlight Search | Index species, dates, locations for system-wide search | P2 |
| Quick Look | Preview Kestrel projects in Finder | P2 |
| Share Extension | Share photos from other apps into Kestrel | P2 |
| Shortcuts / Automation | Expose actions for macOS Shortcuts app | P2 |
| Menu Bar Widget | Quick stats: "Last outing: 3 species, 12 keepers" | P2 |

---

## UI / UX Direction

### Layout Philosophy

A single-window app with three "lanes" (Cull / Polish / Create) accessible via a top-level navigation. Photos flow left to right through the pipeline. The current stage is always visible; the others are one click away.

```
+-----------------------------------------------------------------------+
|  [Cull]          [Polish]          [Create]            [Library]       |
+-----------------------------------------------------------------------+
|                                                                       |
|  Sidebar:          Main Canvas:           Inspector:                  |
|  - Scenes          - Full photo view      - Metadata                  |
|  - Species         - Edit controls        - Quick actions             |
|  - Filters         - Template preview     - Export options            |
|                                                                       |
+-----------------------------------------------------------------------+
|  Film Strip / Thumbnail Bar                                           |
+-----------------------------------------------------------------------+
```

### Visual Identity

- **Color palette:** Muted earth tones as chrome, vibrant photos as the hero. The UI should recede; the birds should pop.
- **Typography:** SF Pro (system) for UI, optional serif for labels/overlays (naturalist feel).
- **Iconography:** Thin line icons, bird-inspired where appropriate but never kitschy.
- **Motion:** Subtle, physics-based animations. Photos slide, fan, stack. No jarring transitions.
- **Dark mode first:** Birders edit in the evening after a day in the field. Default dark, with light option.
- **Density:** Comfortable by default, compact mode available for power users on smaller screens.

---

## Development Phases

### Phase 1 — Foundation (Weeks 1-4)
- [ ] Swift project scaffold, SwiftUI app shell, navigation structure
- [ ] Core ML model conversion (bird detection + quality scoring + species ID)
- [ ] RAW image decoding pipeline (ImageIO / Core Image)
- [ ] Photo import and thumbnail generation
- [ ] SQLite/SwiftData schema for photo metadata
- [ ] Basic library view with grid + detail

### Phase 2 — Cull (Weeks 5-8)
- [ ] ML pipeline integration: detect -> score -> classify per photo
- [ ] Scene grouping algorithm
- [ ] Cull UI: scene-by-scene review, keyboard-driven accept/reject
- [ ] Quality sorting within scenes
- [ ] Species filter and search
- [ ] Batch operations (accept/reject entire scene)

### Phase 3 — Polish (Weeks 9-14)
- [ ] Core Image filter chain: crop, exposure, WB, sharpen, denoise, saturation
- [ ] Real-time edit preview with Metal rendering
- [ ] Smart crop with bird-aware composition
- [ ] One-tap presets (Bird Portrait, Field Guide, Drama, etc.)
- [ ] Background blur / vignette with subject masking
- [ ] Annotation system: species labels, EXIF, field marks, text
- [ ] Watermark system
- [ ] Export pipeline with platform presets

### Phase 4 — Create (Weeks 15-20)
- [ ] Template engine for print products
- [ ] Social collage builder (grids, comparisons)
- [ ] AI style transfer (Core ML Stable Diffusion or API)
- [ ] Text-to-bird-art generation
- [ ] Product mockup previews (hat, shirt, mug, etc.)
- [ ] Print-ready PDF export with bleed and crop marks
- [ ] Personal field guide layout engine

### Phase 5 — Polish & Ship (Weeks 21-24)
- [ ] Performance optimization and profiling
- [ ] Animations and micro-interactions
- [ ] Keyboard shortcuts throughout
- [ ] Accessibility audit (VoiceOver, Dynamic Type)
- [ ] App Store preparation, screenshots, preview video
- [ ] Beta testing with birder community

---

## Open Questions

1. **AI models:** Run Stable Diffusion locally (large model, Apple Silicon only, offline) or call an external API (smaller app, needs internet, ongoing cost)?
2. **Pricing model:** One-time purchase? Subscription? Free with paid Pro features?
3. **eBird integration:** Worth pursuing for v1, or defer? Requires API partnership with Cornell Lab.
4. **POD integration:** Build direct Redbubble/Printful integration, or just export print-ready files and let users upload manually?
5. **Localization:** English-first, but birding is global. CJK support for species names from day one?
6. **Community features:** Should there be any social/sharing component, or keep it purely a local tool?
7. **Existing Kestrel users:** Migration path from Python version? Or clean break?

---

*Document version: 0.1 — 2026-04-16*
*Last updated by: Bruce & Kestrel AI Co-pilot*
