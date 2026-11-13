#!/usr/bin/env python3
"""Compare zsh-bench output with the project baseline, without a tolerance."""
import sys
from decimal import Decimal, InvalidOperation
from pathlib import Path


def read_metrics(path):
    metrics = {}
    for line in Path(path).read_text().splitlines():
        if '=' not in line:
            continue
        name, value = line.split('=', 1)
        if not name or not name.replace('_', '').isalnum():
            continue
        if name in metrics:
            raise ValueError(f'{path}: duplicate metric {name}')
        metrics[name] = value
    if not metrics:
        raise ValueError(f'{path}: no benchmark metrics')
    return metrics


def main():
    if len(sys.argv) != 3:
        print('Usage: check-benchmark.py TARGET CURRENT', file=sys.stderr)
        return 2
    target, current = map(read_metrics, sys.argv[1:])
    failed = False
    for name, expected in target.items():
        actual = current.get(name)
        if actual is None:
            print(f'FAIL {name}: missing')
            failed = True
            continue
        if name.endswith('_ms'):
            wanted, measured = Decimal(expected), Decimal(actual)
            passed = measured.is_finite() and measured >= 0 and measured <= wanted
        else:
            passed = actual == expected
        print(f'{"PASS" if passed else "FAIL"} {name}: {actual} (target {expected})')
        failed |= not passed
    return int(failed)


if __name__ == '__main__':
    try:
        sys.exit(main())
    except (OSError, ValueError, InvalidOperation) as error:
        print(f'Invalid benchmark: {error}', file=sys.stderr)
        sys.exit(2)
