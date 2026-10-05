"""Package frames from visitor_contests_animation_capture.gd into reviewable GIFs."""
import argparse
from pathlib import Path

from PIL import Image


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("contests", nargs="*", help="Optional contest IDs to package.")
    parser.add_argument('--clean-frames', action='store_true',
                        help='Remove only the 60 generated PNG frames per contest after packaging.')
    args = parser.parse_args()
    root = (Path(__file__).resolve().parents[1] / 'build' / 'contest_animation').resolve()
    names = ['arm_wrestling', 'memory_match', 'quick_draw', 'drinking']
    for name in args.contests or names:
        if name not in names:
            parser.error(f'Unknown contest: {name}')
        paths = [root / f'{name}_{index:03d}.png' for index in range(60)]
        frames = []
        for path in paths:
            with Image.open(path) as source:
                frames.append(source.convert('RGB').quantize(colors=128))
        frames[0].save(root / f'{name}.gif', save_all=True, append_images=frames[1:],
                       duration=67, loop=0, optimize=False, disposal=2)
        for frame in frames:
            frame.close()
        sheet = Image.new('RGB', (4800, 600))
        for column, index in enumerate([0, 15, 30, 45, 59]):
            with Image.open(paths[index]) as source:
                sheet.paste(source.convert('RGB'), (960 * column, 0))
        sheet.resize((1920, 240)).save(root / f'{name}_sequence.png')
        sheet.close()
        if args.clean_frames:
            for path in paths:
                # Exact generated names only; no recursive deletion or path traversal.
                assert path.resolve().parent == root
                path.unlink()
        print(f'{name}: packaged 60 frames')


if __name__ == '__main__':
    main()
