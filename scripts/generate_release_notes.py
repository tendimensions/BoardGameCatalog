from pathlib import Path


CHANGELOG_PATH = Path("mobile/CHANGELOG.md")
OUTPUT_PATH = Path("release_notes.txt")
DELIMITER = "---"
TITLE = "# Mobile App Changelog"


def extract_release_notes(changelog_text: str) -> str:
    lines = changelog_text.splitlines()

    try:
        delimiter_index = lines.index(DELIMITER)
    except ValueError as exc:
        raise ValueError(
            f"Delimiter '{DELIMITER}' not found in {CHANGELOG_PATH}"
        ) from exc

    release_note_lines = lines[:delimiter_index]

    if release_note_lines and release_note_lines[0].strip() == TITLE:
        release_note_lines = release_note_lines[1:]

    notes = "\n".join(release_note_lines).strip()
    if not notes:
        raise ValueError(f"No release notes found before delimiter in {CHANGELOG_PATH}")

    return notes + "\n"


def main() -> None:
    changelog_text = CHANGELOG_PATH.read_text(encoding="utf-8")
    release_notes = extract_release_notes(changelog_text)
    OUTPUT_PATH.write_text(release_notes, encoding="utf-8")
    print(f"Wrote release notes to {OUTPUT_PATH}")


if __name__ == "__main__":
    main()
