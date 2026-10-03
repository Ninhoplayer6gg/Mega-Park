"""Regenerates every procedural asset in assets/. Run: python3 tools/art/gen_all.py (needs Pillow)."""
import creatures
import environment
import buildings
import ui_art

if __name__ == "__main__":
    creatures.generate()
    environment.generate()
    buildings.generate()
    ui_art.generate()
    print("assets generated")
