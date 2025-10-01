# CONSEQUENCE GAME - SOLO ROUTE EXPANSION

## Overview
This expansion adds **100x more content** to the solo/alone route where Alex dies, providing a completely different experience from the Alex route. The expansion includes:

- **50+ new scenes** for Day 1 solo survival
- **60+ new scenes** for Day 2 solo survival  
- **Deep psychological exploration** of isolation and guilt
- **Complex resource management** mechanics
- **Multiple survival strategies** and paths
- **Unique encounters** and NPCs for solo players

## Key Features

### Day 1 Solo Route Expansion
- **Apartment Fortification Hub**: Detailed choices for securing your home
- **Water Management**: Multiple strategies for water collection and storage
- **Power Management**: Decisions about electricity, lights, and traps
- **Barricade Work**: Fortifying doors, windows, and interior spaces
- **Roof Setup**: Establishing escape routes and reconnaissance points
- **Radio Monitoring**: Scanning for signals and broadcasting
- **Psychological Struggle**: Dealing with isolation and guilt
- **Night Events**: Multiple possible night encounters based on your preparations

### Day 2 Solo Route Expansion
- **Street Scavenging**: Multiple locations to raid for supplies
- **Radio Hunting**: Following mysterious broadcasts and signals
- **Apartment Fortification**: Further securing your base
- **Building Exploration**: Checking other units for supplies/survivors
- **Psychological Day 2**: Deeper exploration of guilt and redemption
- **Roof Reconnaissance**: Mapping the area and planning escape routes
- **Mysterious Broadcaster**: Encounter with Dr. Sarah Chen
- **Courthouse Safe Zone**: Option to join a survivor network

### Psychological Depth
- **Guilt Confrontation**: Facing the weight of Alex's death
- **Redemption Paths**: Ways to seek redemption through helping others
- **Isolation Management**: Coping with complete solitude
- **Memory and Memorial**: Honoring the dead
- **Vows and Promises**: Making commitments to the deceased

### Resource Management
- **Water Systems**: Bathtub filling, bleach treatment, container collection
- **Power Systems**: Breaker management, trap wiring, power hoarding
- **Supply Networks**: Scavenging, trading, and resource allocation
- **Fortification Materials**: Tools, barricades, and defensive systems

## File Structure

### Core Files
- `solo_route_day1_expansion.js` - Day 1 solo route content
- `solo_route_day2_expansion.js` - Day 2 solo route content  
- `solo_route_integration.js` - Integration script and additional scenes
- `consequence_game_solo_expansion.html` - Complete HTML game with expansions

### Integration
The expansion integrates seamlessly with the existing game by:
1. Adding new scenes to the STORY_DATABASE
2. Updating existing solo route scenes to point to new content
3. Maintaining all existing game mechanics and systems
4. Preserving the original Alex route unchanged

## Gameplay Paths

### Compassionate Protector Path
- Face guilt head-on
- Seek redemption through helping others
- Join survivor networks
- Focus on medical and security work

### Cold-Blooded Survivor Path  
- Suppress guilt and emotions
- Focus purely on survival
- Avoid other survivors
- Prioritize resource hoarding

### Calculated Strategist Path
- Rationalize choices
- Focus on information gathering
- Build supply networks
- Maintain independence

### Psychological Breakdown Path
- Struggle with isolation
- Experience mental health challenges
- Make increasingly desperate choices
- Risk everything for human contact

## Technical Implementation

### Scene Structure
Each new scene follows the established pattern:
```javascript
{
  "id": "scene_name",
  "text": "Scene description...",
  "choices": [
    {
      "id": "choice_id",
      "text": "Choice text...",
      "goTo": "target_scene",
      "effects": {
        "stats": { "health": 1, "stress": -1 },
        "persona": { "nice": 1 },
        "flagsSet": ["flag_name"],
        "inventoryAdd": ["item_name"],
        "relationships": { "NPC": 2 },
        "pushEvent": "Event description..."
      },
      "tags": ["nice"],
      "req": { "flags": ["required_flag"] },
      "blockedReason": "Why choice is blocked"
    }
  ],
  "timeDelta": 1
}
```

### Integration Points
- **act1_alone_hub** → **solo_apartment_hub** (Day 1 hub)
- **solo_day2_morning_hub** (Day 2 hub)
- **solo_courthouse_safe_zone** (Community option)
- **solo_end_of_day1** → **solo_day2_morning_hub** (Day transition)

## Content Highlights

### Unique Solo Encounters
- **Dr. Sarah Chen**: Mysterious broadcaster coordinating survivors
- **Building Residents**: Other survivors hiding in apartments
- **Neighbor Check**: Exploring other units for supplies/survivors
- **Signal Tracing**: Following mysterious broadcasts to their source

### Psychological Scenes
- **Guilt Confrontation**: Sitting with Alex's memory
- **Redemption Path**: Seeking to make Alex's death meaningful
- **Isolation Management**: Coping with complete solitude
- **Memory and Memorial**: Honoring the dead

### Resource Management Scenes
- **Water Management**: Multiple strategies for water collection
- **Power Management**: Electricity decisions and trap wiring
- **Supply Scavenging**: Raiding pharmacies, groceries, hardware stores
- **Fortification Work**: Building defenses and escape routes

## Usage Instructions

1. **Load the HTML file** in a web browser
2. **Start a new game** and choose the "Ignore" option when Alex knocks
3. **Explore the solo route** with its expanded content
4. **Make meaningful choices** that affect your survival and psychology
5. **Experience different paths** based on your decisions

## Expansion Statistics

- **Total New Scenes**: 120+
- **New Choices**: 400+
- **New NPCs**: 3 (Dr. Sarah Chen, Neighbors, Building Residents)
- **New Items**: 20+ (medical supplies, tools, materials)
- **New Flags**: 50+ (tracking progress and consequences)
- **New Relationships**: 5+ (Sarah, Neighbors, etc.)

## Future Expansion Potential

The solo route expansion provides a foundation for:
- **Day 3+ Content**: Further solo survival challenges
- **Community Building**: Establishing your own survivor network
- **City Exploration**: Venturing further into the infected city
- **Psychological Evolution**: Deeper character development
- **Endgame Scenarios**: Multiple possible endings for solo players

This expansion transforms the solo route from a simple "Alex dies" path into a rich, complex survival experience that rivals the Alex route in depth and content.