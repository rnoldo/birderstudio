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

## Open Questions We Need to Answer by Building

- What's the real-world accuracy of cloud vision models on bird species ID from field photos (not clean stock images, but backlit, partially obscured, distant shots)?
- What's the right UX for uncertain IDs? How do we present confidence without overwhelming?
- How much EXIF/GPS data can we practically use for species narrowing? (If GPS says "Minnesota in January", it's probably not a Painted Bunting.)
- What RAW formats does Core Image handle natively, and which need additional work?
- How do birders actually want to interact with AI-generated content? Full drafts to edit, or sentence fragments to assemble?
