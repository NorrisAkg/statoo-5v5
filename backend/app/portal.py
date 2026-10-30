"""Explicit public surface of the transitional legacy portal."""
from pathlib import Path

from fastapi.staticfiles import StaticFiles


PUBLIC_FILES = frozenset({
    'index.html', 'app.mjs', 'interaction.mjs', 'button-state.mjs',
    'validation.mjs', 'vendor/zod.mjs', 'vendor/ZOD-LICENSE.txt',
    'config.mjs', 'registration-draft.mjs', 'client.mjs', 'domain.mjs',
    'summary.mjs', 'pwa.mjs', 'sw.js', 'styles.css', 'manifest.webmanifest',
    'team-names.json', 'icons/icon-192.png', 'icons/icon-1024.png',
    'icons/logo.jpg', 'icons/logo-transparent.png', 'icons/favicon.png',
    'icons/apple-touch-icon.png', 'fonts/Poppins-Regular.ttf',
    'fonts/Poppins-SemiBold.ttf', 'fonts/OFL.txt',
})


class PortalFiles(StaticFiles):
    def lookup_path(self, path):
        # "." allows StaticFiles' directory-index handling, not directory listing.
        if Path(path).as_posix() not in PUBLIC_FILES | {'.'}:
            return '', None
        full_path, stat_result = super().lookup_path(path)
        if stat_result is not None:
            # A public filename must not alias a private file via a symlink.
            relative = Path(full_path).relative_to(Path(self.directory).resolve())
            if relative.as_posix() not in PUBLIC_FILES | {'.'}:
                return '', None
        return full_path, stat_result
