# Birder Studio

## What We're Building

Every birder knows the feeling: you come home from a great morning in the field, SD card full of 400 photos, excited about that one moment when the Painted Bunting landed three meters away. Then you sit down at the computer and the excitement dies. Two hours of scrolling through blurry shots, duplicates, empty branches. By the time you find your keepers, edit them, and write a post — half your evening is gone.

We're building the tool that gives birders their evenings back.

Birder Studio is a macOS app where you drop in your photos and AI handles the tedious work — culling the bad shots, finding your best frames, identifying species, and helping you share your sightings with the world. The birder focuses on the creative and joyful parts: choosing favorites, telling the story, connecting with the community.

## Who It's For

Birders who shoot with real cameras. The ones with a 100-400mm or 150-600mm on a mirrorless body, who come home with hundreds of RAW files after a morning at the wetlands. They're active on eBird, they post to Instagram or Twitter, they might write a birding blog. They care about their photos and they care about accuracy — they'll argue about whether that's a Cooper's Hawk or a Sharp-shinned.

These people are obsessive, knowledgeable, and underserved. No tool in the world is built for their specific workflow. We're going to build it.

## The Experience

### The Core Flow

**1. "I just got back from birding"**

You plug in your SD card or drag a folder into Birder Studio. The app reads the EXIF data — date, time, GPS — and creates a session: "March 15, 2026 — Bolsa Chica Ecological Reserve." RAW files, JPEGs, HEIF — all handled.

This takes seconds. No setup, no album creation, no tagging. Just drop and go.

**2. AI goes to work**

While you make coffee, Birder Studio is:

- Grouping your 400 photos into bursts and clusters of similar shots
- Scoring every frame: sharpness, exposure, composition, how clearly the bird is visible
- Flagging the obvious throwaways (motion blur, empty frame, branch-only shots)
- Picking the best 1-2 from each burst of similar shots
- Identifying the bird species in every frame — with confidence levels

This is the hard part. This is what makes us different from everything else. A birder shouldn't have to scroll through 15 nearly-identical shots of a heron taking off to find the one where the wings are fully spread and the eye is sharp. The AI should find it.

**3. Review, don't sort**

You come back to a curated view. The AI's picks are highlighted. The rejected shots are dimmed but not hidden — you can always override. You're reviewing decisions, not making them from scratch.

You flip through: "Yes, yes, no that one's better actually, yes, oh I missed this one — add it back." Five minutes and you have your 30-40 keepers from 400 shots.

Species tags are already on every photo. Most are right. The Downy vs Hairy Woodpecker call might be uncertain — the app shows you "Downy Woodpecker (73%)" and you tap to confirm or correct. Over time, your corrections make the AI better for your local species.

**4. Your gallery, organized**

Keepers are organized by species within the session. You see your session as a story: "Today I saw 12 species." Each species section shows your best shots, the count, behavior notes you can add.

EXIF data is front and center — birders care about focal length, shutter speed, ISO. Not buried in a menu. Right there.

**5. Make it beautiful**

Quick, focused editing. Exposure, white balance, crop. Not 47 sliders — the adjustments birders actually use. A crop tool with guides. One-click watermark with your name/logo.

We're not building Lightroom. If someone needs advanced editing, they export to Lightroom. We handle the 80% case where you just need to brighten the exposure, crop tighter on the bird, slap your watermark on, and share.

**6. Share your sighting**

Select a photo. The AI drafts a post:

> Spotted this stunning male Painted Bunting at Bolsa Chica this morning! First time seeing one at this reserve — been waiting all spring. The colors in person are even more unreal than the photos.
>
> Canon R7 + RF 100-500mm | 500mm, f/7.1, 1/1600s, ISO 800

You tweak the words, hit copy, paste into Twitter. Done.

Or generate an eBird checklist note. Or an Instagram caption with hashtags. Or a species profile article for your blog. The AI knows birding — it writes like a birder, not like a generic content mill.

### Beyond the Core

These aren't afterthoughts — they're experiences that make the product whole once the core is solid:

**Duplicate Detective** — Not just "these two photos are similar." Smart grouping that understands bursts, sequences, and slight repositions. Visual diff showing exactly what's different between two shots. The birder picks the winner from a smart comparison, not a wall of thumbnails.

**Life List Integration** — Your sessions build into a personal life list. "You've now photographed 147 species." A quiet, persistent reward for using the app. Potentially syncs with eBird in the future.

**Species Encyclopedia** — When you ID a bird, you can pull up a rich species card: range map, seasonal occurrence, similar species to watch for, conservation status. Useful in the moment ("is this actually rare here?") and educational.

**Smart Collections** — Auto-generated albums: "Best of 2026", "Raptors", "This Week's New Species", "Your Top-Rated Shots." The app learns what you care about.

**Export Workflows** — Export keepers at web resolution with watermark. Export full-res for print. Export a contact sheet of the session. Batch export by species. Whatever the birder's downstream need is.

## What We Believe

**The AI must be great, not just present.** A species ID that's wrong 30% of the time is worse than no species ID at all. Birders are precise people. If the AI calls a Red-tailed Hawk a Red-shouldered Hawk, they'll never trust it again. We use the best available models — cloud AI for identification when accuracy matters, local models for speed when it's just quality scoring. We don't compromise on accuracy to save API costs.

**Hybrid AI architecture.** Local on-device models (Core ML, Vision) handle the fast, bulk work: quality scoring, blur detection, duplicate grouping. These are free, instant, and work offline. Cloud AI (Claude, specialized vision models) handles the hard stuff: species identification, content generation. This costs money per call, and that's fine — it's where the value is.

**The app should feel like a darkroom, not a dashboard.** Birders are visual people dealing with visual content. The UI should be dark, photo-centric, immersive. Photos are large. Controls are minimal and contextual. No widgets, no cards, no dashboards. When you're reviewing your shots, the photos are the experience.

**Speed is a feature.** The entire point is saving time. If AI triage takes 20 minutes for 400 photos, we've failed. Target: under 3 minutes from import to curated gallery for a typical session. This means aggressive parallelization, progressive loading, background processing with live updates.

**Respect the birder's expertise.** The AI suggests, the birder decides. Never auto-delete. Never hide photos without a way to see them. Always show confidence levels. Always allow corrections. The birder knows more about birds than the AI does — our job is to narrow their workload, not override their judgment.

## Technical Foundation

| Layer | Choice | Why |
|-------|--------|-----|
| App | Native SwiftUI, macOS 14+ | Performance for image-heavy workflows. Full access to Vision, Core ML, Metal, Core Image. Native drag-and-drop, file system access, RAW codec support. Nothing else comes close for this use case. |
| Data | SwiftData | Local-first persistence. Swift-native. Handles our entity graph (sessions, photos, species, drafts) well. |
| Image pipeline | Core Image + Metal | GPU-accelerated processing. Native RAW support (CR2, CR3, NEF, ARW, RAF via Apple codecs). Real-time preview of adjustments. |
| Local AI | Vision framework + Core ML | On-device quality scoring, blur detection, face/animal detection. Free, fast, offline. |
| Cloud AI | Claude API (vision + text) | Species identification from photos. Content generation. Best accuracy and writing quality available. |
| Species data | eBird/Clements taxonomy | The standard birding taxonomy. ~10,000 species worldwide. We ship a local copy and update periodically. |

## How We'll Know It's Working

Not vanity metrics. Real signals that birders love this:

- **Do they come back after the second session?** First session is curiosity. Second session means it's becoming part of their workflow.
- **How fast do they go from import to done?** If we're actually saving time, this number should be dramatically lower than their old workflow.
- **Do they correct the AI less over time?** Species ID accuracy improving means the system is learning and earning trust.
- **Do they share from the app?** If they're using content generation and copying to clipboard, the AI writing is good enough to trust.
- **Do they tell other birders?** Word of mouth in the birding community is the real growth engine. If the product is great, birders will talk about it at their local Audubon chapter.

## Revenue

We're not optimizing for revenue right now. We're building something great and getting it into birders' hands.

The model that makes sense long-term: **The app is free. AI features use credits.** Everything that runs locally (organization, editing, watermarks, export) costs nothing forever. AI-powered features (species ID, quality scoring via cloud, content generation) consume credits. You get a generous free tier each month — enough to be useful. Power users buy more.

This aligns cost with value. The birder who processes 10 sessions a week gets more value and pays more. The casual weekend birder stays free or nearly free. We never gate features behind a paywall — every user gets the full experience, just with different AI volume.

Specifics of pricing tiers we'll figure out once we have real usage data and know our actual costs per session. Premature optimization of pricing is a distraction.

## The birding.me Domain

- Marketing site: what the product is, download link, species ID gallery showcasing accuracy
- Account: API key management, credit balance, usage history
- Future: public galleries at birding.me/username — "here are my best shots from 2026"
- Future: community features — but only after the core product is exceptional

## What Exists Today and Where We Fit

No one is doing what we're doing. That's not arrogance — it's the gap:

- **Lightroom** is the gold standard for photo editing but knows nothing about birds. It can't tell a warbler from a sparrow, can't auto-cull, can't write your Instagram caption.
- **Merlin** (by Cornell Lab) is great at bird ID from a single photo or audio, but it's a field guide tool. No batch processing, no photo management, no editing, no content creation.
- **eBird** is where the data lives — checklists, sightings, range maps. But it's a database with a web UI, not a creative tool. No photo workflow.
- **Apple Photos / Google Photos** are generic. AI tagging says "bird." We say "juvenile Red-tailed Hawk, light morph."

We sit in the middle of all of these. The workflow bridge between camera and community that none of them provide.

## AI Technical Strategy

We don't need large models for most of the heavy lifting. Research shows all three core AI tasks can run primarily on-device, with cloud AI reserved for the genuinely hard cases.

### Bird Species Identification — Tiered Pipeline

The single most important architectural decision: **use eBird's location + date frequency data as a Bayesian prior**. For a photo taken at a specific GPS coordinate in a specific month, eBird tells us which species have been reported there and how frequently. This narrows ~10,000 worldwide species down to ~100-150 local candidates. It transforms a mediocre classifier into a great one. This is what makes Merlin so accurate — and the data is freely available via eBird's API.

**Tier 1 — On-device Core ML (free, instant, handles ~50-65% of photos)**
- EfficientNet-B2 or B4 fine-tuned on the iNaturalist bird subset (~900+ species for North America)
- Convert to Core ML (~7-15 MB model), runs in ~10-20ms per photo on Apple Silicon
- Combined with eBird location+date prior: if top-1 confidence > 85% AND species is expected at this location/date → accept
- Training data: iNaturalist competition datasets (publicly available, millions of bird images)

**Tier 2 — Cloud specialized model (cheap, handles ~20-30% of photos)**
- For uncertain cases (confidence 50-85%, or species unexpected at location)
- Self-hosted model on Replicate or similar: a larger ViT or ensemble model with location priors
- Cost: < $0.005 per image

**Tier 3 — Claude Vision (expensive, handles ~10-20% of photos)**
- For genuinely difficult cases: confidence < 50%, rare species, juveniles, heavily backlit/distant
- Also used when the user explicitly requests a second opinion
- Cost: ~$0.02-0.04 per image

**Estimated cost per 400-photo session: $0.60-3.00** (vs. $4-20 if everything went to Claude Vision)

No open-source model currently covers all ~10,000 eBird species at production quality. Best available: ViT fine-tuned on CUB-200 (200 species, ~90% top-1) and various EfficientNet models on NABirds (555 species). For North America coverage (~900-1,000 species), we'll need to fine-tune on iNaturalist data. The model will be weakest on: difficult species pairs (Cooper's vs Sharp-shinned Hawk), juveniles in non-standard plumage, and rare species with few training photos. These are exactly the cases that fall through to Tier 2/3.

### Photo Quality Scoring — Fully On-Device

No cloud calls needed. Total cost: $0. Total latency: ~50-80ms per photo.

```
Photo
  ├─→ [Apple Vision: Subject Segmentation] → bird mask + background mask
  ├─→ [YOLOv8-nano Core ML: Bird Detection] → bounding box (~15ms, ~6MB model)
  ├─→ [NIMA MobileNetV2 Core ML] → aesthetic score 1-10 (~10ms, ~14MB model)
  ├─→ [Laplacian variance on bird ROI] → sharpness score (<2ms)
  ├─→ [Head crop + Laplacian] → eye sharpness proxy (<2ms)
  ├─→ [CIAreaHistogram] → exposure score (<2ms)
  ├─→ [Saliency + rule-of-thirds geometry] → composition score (~20ms)
  ├─→ [Background mask + frequency analysis] → background quality (<5ms)
  └─→ Weighted combination → final quality rank
```

Key models:
- **NIMA** (Neural Image Assessment, MobileNetV2 backbone): predicts aesthetic score distribution. Well-studied, converts cleanly to Core ML. SRCC ~0.88 on standard benchmarks.
- **YOLOv8-nano**: for bird detection/bounding box. Pre-trained bird detectors exist on NABirds/CUB-200 datasets. ~6MB model.
- **Traditional CV** handles sharpness (Laplacian), exposure (histogram), and background quality (frequency analysis) with no ML overhead at all.

Bird-specific quality signals that matter:
- **Eye sharpness** — the most important criterion in bird photography. Detect bird → crop head region (upper 30% of bounding box) → Laplacian variance on that crop. Simple but effective.
- **Background quality** — segment bird from background using Apple's VNGenerateForegroundInstanceMask (macOS 14+), analyze background region's frequency content. Low variance = smooth bokeh = good.
- **Subject prominence** — ratio of bird bounding box to total frame area. Larger bird in frame = better.

### Duplicate Detection & Burst Grouping — Fully On-Device

No cloud calls needed. Total cost: $0. Total time for 500 photos: ~15-30 seconds.

**Stage 1: EXIF timestamp clustering (< 1ms)**
Sort by capture time. Photos within 2-3 seconds = likely burst. This alone catches most mechanical bursts and is essentially free.

**Stage 2: Visual fingerprinting with Apple VNFeaturePrint (5-15 sec)**
Apple's built-in `VNGenerateImageFeaturePrintRequest` produces a compact embedding per image. Compare via `computeDistance(to:)`. Thresholds:
- Distance < 5.0: near-identical (true duplicate / same burst frame)
- Distance 5.0-15.0: same scene, minor differences
- Distance 15.0-25.0: similar content (same subject, different shot)
- Distance > 25.0: unrelated

Feature prints are cacheable — compute once, store alongside the image, never recompute.

**Stage 3: pHash as complementary fast filter (2-4 sec)**
Perceptual hashing (DCT-based) catches exact and near-exact duplicates. Hamming distance 0-2 = true duplicate, 3-8 = same burst. Good for catching RAW vs JPEG of the same shot.

**Stage 4: Hierarchical clustering on VNFeaturePrint distances (< 100ms)**
Agglomerative clustering produces a dendrogram — cut at different thresholds to get "tight burst" vs "same encounter" vs "same session" groupings. For 500 photos the distance matrix is only 250K entries, trivial to compute.

**Stage 5: Best-of-burst selection (6-12 sec for all bursts)**
Within each burst cluster, score and rank:
- Sharpness on subject region (40% weight) — Laplacian variance on saliency crop
- Exposure quality (20%) — histogram analysis, penalize highlight/shadow clipping
- Subject size in frame (20%) — saliency region area relative to frame
- Composition (10%) — subject centroid distance from rule-of-thirds intersections
- Noise level (10%) — variance in smooth background regions

Present the top pick highlighted, runner-up accessible, rest dimmed.

### Total On-Device AI Budget

| Component | Model Size | Latency per Photo |
|-----------|-----------|-------------------|
| EfficientNet-B2 (species ID) | ~7-15 MB | ~10-20ms |
| NIMA MobileNetV2 (aesthetic score) | ~14 MB | ~10ms |
| YOLOv8-nano (bird detection) | ~6 MB | ~15ms |
| VNFeaturePrint (duplicate detection) | 0 (system) | ~15-30ms |
| Traditional CV (sharpness, exposure, etc.) | 0 | ~5-10ms |
| **Total** | **~30-35 MB** | **~55-85ms** |

For a 400-photo session, the full pipeline (triage + quality scoring + duplicate detection + burst selection) should complete in **under 60 seconds** on Apple Silicon. The user drops their photos in, goes to make coffee, and comes back to a curated gallery. Only species identification on uncertain photos touches the network.

## Open Questions We Need to Answer by Building

- What's the real-world accuracy of our tiered species ID pipeline on actual field photos (backlit, partially obscured, distant shots)? Lab benchmarks won't tell us this — we need to test on real birding sessions.
- How well does VNFeaturePrint handle bird-specific similarity? It's a general-purpose embedding — it might confuse two different birds on similar perches, or split a burst where the bird dramatically changes pose.
- What's the right UX for uncertain IDs? How do we present confidence without overwhelming?
- What's the optimal eBird frequency threshold for the location prior? Too aggressive and we miss genuine rarities. Too loose and we don't help enough.
- What RAW formats does Core Image handle natively, and which need additional codecs?
- How do birders actually want to interact with AI-generated content? Full drafts to edit, or fragments to assemble?
