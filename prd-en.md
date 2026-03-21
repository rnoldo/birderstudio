# Birder Studio — Product Requirements Document

## Vision

Birder Studio is the AI-powered post-session workflow tool for birders. It turns the most painful part of birding — sorting through hundreds of photos after a session — into a fast, delightful experience.

**One-liner**: Drop your photos in, get a curated, species-tagged, share-ready gallery out.

## Why This Exists

After every birding session, birders face the same tedious process:

1. Import 200-500+ photos from their camera
2. Manually scroll through to find the good ones (most are blurry, duplicates, or empty branches)
3. Try to identify species in unclear shots
4. Edit the keepers
5. Write captions and post to social media or birding communities (eBird, Merlin, forums)

This takes hours. Steps 1-3 are pure drudgery. No existing tool understands birds — Lightroom can sort photos but can't tell a warbler from a sparrow. Merlin can identify birds from audio but not from DSLR photos in bulk.

Birder Studio is the missing tool that sits between the camera and the sharing.

## Target User

**Primary**: Serious hobbyist birders with dedicated camera gear (DSLR/mirrorless + telephoto lens). They go out 2-4 times per week, shoot hundreds of photos per session, and actively share on eBird, Instagram, birding forums, or personal blogs.

**Why not casual birders?** iPhone birders have fewer photos and simpler needs — Apple Photos is good enough. Our value scales with volume and the need for species identification.

**Why not pro wildlife photographers?** They already have established Lightroom/Capture One workflows and won't switch. We complement their workflow rather than replace it.

## Core Product Principles

1. **Session-first, not photo-first** — The atomic unit is a birding session (date + location + batch of photos), not individual photos. Everything flows from "I just got back from birding."
2. **AI does the boring work** — Culling, deduplication, species ID, and quality scoring happen automatically. The birder makes creative decisions, not sorting decisions.
3. **Opinionated defaults, easy overrides** — The AI picks the best shots and identifies species. The birder can always correct it, but shouldn't have to most of the time.
4. **Fast to share** — From import to social post should take minutes, not hours.

## MVP Feature Set

### The Core Loop: Session Import → AI Cull → Review → Share

#### 1. Session Import
- Drag-and-drop a folder (or select from Finder)
- Auto-extract EXIF: date, time, GPS location, camera settings
- Auto-create a session entity (date + location name via reverse geocoding)
- Support RAW formats (CR2, CR3, NEF, ARW, RAF) + JPEG/HEIF

#### 2. AI Triage (the killer feature)
- **Duplicate/burst grouping** — Perceptual hashing to cluster near-identical shots
- **Quality scoring** — Rate each photo on sharpness, exposure, composition, and bird visibility
- **Auto-cull** — Flag obviously bad shots (completely blurry, empty frame, overexposed) so the birder can dismiss them in one click
- **Best-of-group selection** — From a burst of 15 similar shots, highlight the 1-2 best
- **Species identification** — Auto-tag bird species using Vision/Core ML. Show confidence level. Support "uncertain" for difficult IDs

The birder's review experience: open the session, see the AI's picks highlighted, quickly confirm/reject, done.

#### 3. Session Gallery
- Grid view of keepers, organized by species
- Star rating (1-5) for personal favorites
- Side-by-side comparison mode for choosing between similar shots
- EXIF metadata panel (focal length, shutter speed, ISO — birders care about these)
- Species info panel (common name, scientific name, conservation status)

#### 4. Quick Edit
- Basic adjustments: exposure, contrast, saturation, white balance, sharpness
- Crop with rule-of-thirds and golden ratio guides
- One-click watermark (customizable text/logo, position, opacity)
- **Not** a full photo editor — we complement Lightroom, not replace it

#### 5. AI Content Generation
- Select a photo → generate a social media post:
  - **Twitter/X**: Short, engaging caption with species name, location, fun bird fact
  - **Instagram**: Longer caption with hashtags and storytelling
  - **eBird checklist note**: Factual observation note with behavior, count, habitat
  - **Blog/article**: Educational piece about the species
- The birder edits the AI draft, copies to clipboard, pastes into their platform
- Powered by Claude API with birding-domain system prompts

### What's NOT in MVP

- Video editing (Phase 2)
- Direct social media publishing — clipboard is fine for v1
- Product creation (prints, merch)
- Collaboration / sharing between birders
- iOS/iPad version
- Cloud sync
- eBird API integration for auto-submitting checklists (Phase 2, big opportunity)

## Platform & Distribution

- **macOS 14+ (Sonoma)** — Native SwiftUI app
- **Why macOS only for now**: Our target user processes photos at a desk. macOS gives us best performance for image processing (Metal, Core Image), native file system access, and RAW format support via Apple's frameworks.
- **Distribution**: Direct download from birding.me first, Mac App Store later (sandboxing constraints may limit file access)

## Monetization (Initial Thinking)

**Freemium with session limits:**
- **Free tier**: 5 sessions/month, basic AI triage, no content generation
- **Pro** ($9.99/month or $79.99/year): Unlimited sessions, full AI triage, content generation, watermarking
- **Lifetime**: $199 one-time (early adopter pricing)

Rationale: Subscription funds the Claude API costs for content generation. The AI triage uses local models (no ongoing cost per user), so the free tier is sustainable.

## Architecture Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Platform | Native SwiftUI | Performance for image-heavy workflows, macOS API access |
| Persistence | SwiftData | Modern, Swift-native, good enough for local-first app |
| Image processing | Core Image + Metal | GPU-accelerated, handles RAW, ships with macOS |
| Bird identification | Core ML (on-device) | Fast, offline-capable, no API cost per photo |
| Content generation | Claude API | Best writing quality, understands nuance and tone |
| AI triage/scoring | On-device (Vision + Core ML) | Must be fast and work offline — can't send 500 photos to an API |

## Key Metrics (How We Know It's Working)

- **Session completion rate** — % of imported sessions where the user finishes review and has keepers
- **Time from import to first share** — Target: under 5 minutes for a 200-photo session
- **AI accuracy** — Species ID accuracy rate, cull false-positive rate (good photo marked bad)
- **Retention** — Weekly active sessions per user

## The birding.me Domain

- **birding.me** = marketing site + account management + license activation
- The app itself is local-first, no cloud dependency for core features
- Future: optional cloud backup of curated galleries, sharing public galleries via birding.me/username

## Competitive Landscape

| Tool | What it does | Gap we fill |
|------|-------------|-------------|
| Adobe Lightroom | Pro photo editing + organization | No bird awareness, no AI cull, no species ID |
| Apple Photos | Consumer photo management | No birding features, weak for RAW, no AI triage |
| Merlin Bird ID | Bird identification from audio/photos | Single photo at a time, no batch, no editing, no content |
| eBird | Birding checklist + community | No photo management, text-only checklists |
| Canva | Social media content creation | Generic, no birding context, no photo triage |

**Our unique position**: The only tool purpose-built for the birder's post-session photo workflow, with AI that actually understands birds.

## Open Questions

- [ ] Can we train/fine-tune a Core ML model for bird species ID that's accurate enough? Or should we start with Apple's built-in Vision animal classification and iterate?
- [ ] Should we support Windows/Linux eventually? (Tauri could be a future path, but native macOS is the right v1 choice)
- [ ] Partnership opportunity with eBird/Cornell Lab? Their taxonomy database would be invaluable
- [ ] What RAW format support does Core Image provide out of the box vs. what needs additional codecs?
