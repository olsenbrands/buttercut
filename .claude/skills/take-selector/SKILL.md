---
name: take-selector
description: Intelligent take selection for talking-head videos. Detects repeated takes, scores them by completeness/fluency/energy, and picks the best one. Use when user says "pick the best take", "remove retakes", "clean up my footage", "smart edit", or has raw footage with multiple attempts at the same line.
---

# Skill: Smart Take Selector

Analyzes raw talking-head footage to detect repeated takes of the same content and intelligently select the best version of each. Runs as a pre-roughcut stage.

## When to Use

- Speaker recorded multiple attempts at the same line/paragraph
- Raw footage has false starts, stutters, and retries
- User wants automated "rough assembly" from unedited footage
- Before running the roughcut skill (this feeds into it)

## Prerequisites

- Video must have a WhisperX transcript (word-level timestamps)
- Read `~/.buttercut-env.json` for paths

## Pipeline

### Step 1: Segment Detection

Find take boundaries using silence gaps > 1.0 second:

```bash
ruby $silence_detector "/path/to/video.MOV" /tmp/silence_map.json
```

Parse the silence map. Any silence >= 1.0s is a potential take boundary. Split the transcript into segments at these boundaries.

### Step 2: Group Repeated Takes

Compare each segment's text to every other segment using token similarity:

```ruby
# Simple Jaccard similarity on word tokens
def similarity(text_a, text_b)
  words_a = text_a.downcase.split(/\s+/).to_set
  words_b = text_b.downcase.split(/\s+/).to_set
  intersection = (words_a & words_b).size.to_f
  union = (words_a | words_b).size.to_f
  union.zero? ? 0.0 : intersection / union
end
```

If similarity > 0.7, they're likely the same content (a retake). Group them together.

### Step 3: Score Each Take

For each take in a group, calculate these scores (0.0 to 1.0):

**Completeness (from transcript):**
- Did the speaker finish the sentence/thought?
- Longest take in the group gets highest score
- Partial sentences score lower

**Fluency (from transcript):**
- Count filler words: "um", "uh", "like", "you know", "basically", "actually", "I mean", "so", "right"
- Count false starts: repeated word beginnings ("I... I... I think")
- Fewer fillers/stutters = higher score
- Formula: `1.0 - (filler_count / total_word_count)`

**Pacing (from timestamps):**
- Calculate words per second for the take
- Ideal range: 2.0 - 3.5 words/second (natural speaking pace)
- Score drops as pace deviates from this range
- Formula: `1.0 - (abs(wps - 2.75) / 2.75).clamp(0, 1)`

**Energy (from audio - via ffmpeg):**
```bash
ffmpeg -i input.mov -ss START -to END -af "astats=metadata=1:reset=1" -f null - 2>&1 | grep RMS_level
```
- Higher RMS = more confident delivery
- Normalize across takes in the same group
- Later takes often have higher energy (more rehearsed)

**Overall Score:**
```
score = (completeness * 0.35) + (fluency * 0.30) + (pacing * 0.20) + (energy * 0.15)
```

### Step 4: Select Best Takes

For each group of repeated takes:
1. Pick the take with the highest overall score
2. If scores are within 0.05 of each other, prefer the later take (more rehearsed)
3. Flag any group where the top two scores are very close (within 0.02) for human review

### Step 5: Output

Generate a take selection report:

```yaml
# take_selection.yaml
video: /path/to/video.MOV
total_segments: 15
unique_segments: 8  # after deduplication
retake_groups: 4    # groups where speaker repeated content
flagged_for_review: 1  # ambiguous selections

selections:
  - segment: 1
    start: 0.0
    end: 12.45
    type: unique  # no retakes, kept as-is

  - segment: 2
    start: 12.45
    end: 24.30
    type: selected  # best of 3 takes
    score: 0.87
    alternatives:
      - start: 24.30, end: 35.10, score: 0.72
      - start: 35.10, end: 47.80, score: 0.65
    reason: "Highest fluency (no fillers), complete sentence, natural pacing"

  - segment: 3
    start: 50.20
    end: 62.10
    type: review  # needs human decision
    score: 0.81
    alternatives:
      - start: 62.10, end: 73.50, score: 0.80
    reason: "Scores too close to call — take 1 has better pacing, take 2 has fewer fillers"
```

### Step 6: Feed into Roughcut

The take selection YAML can be used as input to the roughcut skill. The roughcut skill reads the selected segments and builds the timeline from the best takes only.

## User Interaction

- If user says "clean up my footage" or "remove retakes" → run this skill
- If user says "which take is better?" → show the scoring breakdown
- If segments are flagged for review, present alternatives with timestamps so user can listen and choose
- After user confirms selections, proceed to roughcut

## Filler Words List

Detect and count these in transcripts:
```
um, uh, ah, er, hmm, like, you know, basically, actually, literally,
I mean, so, right, okay, well, kind of, sort of, I guess, I think,
honestly, really, just, stuff, things, whatever
```

## False Start Patterns

Detect these repetition patterns:
```
"I... I..." → false start
"The... the thing..." → false start
"We need to... we need to focus..." → restart
"So the... actually the..." → revision
```

Keep the version that completes the thought.
