#!/usr/bin/env python3
"""Compatibility entry point for the original cyber snake sprite generator.

v1.2.1 restores the exact pre-glossy artwork requested by the user.
"""
from pathlib import Path
import runpy

if __name__ == '__main__':
    runpy.run_path(str(Path(__file__).resolve().with_name('generate_classic_snakes.py')), run_name='__main__')
