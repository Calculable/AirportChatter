# Station catalog

This document describes a **local, Git-ignored** snapshot, not a redistributed catalog. See the repository README for setup and licensing limitations. Review of https://www.liveatc.net/legal/ on September 22, 2026 found no explicit permission to redistribute the directory. Sections 2.1, 3.4, 3.13, 3.15, and 4 address permitted use, dedicated apps, retrieval, direct links, and rights. This is a conservative repository decision, not a definitive legal assessment.

`AirportChatter/Data/default_stations.json` contains a snapshot of LiveATC's public feed directory collected on September 22, 2026.

Source: https://www.liveatc.net/feedindex.php?type=all

## Coverage

The collection visited all 12 directory categories and their state, province, and ARTCC subdivisions: 161 leaf pages in total. It collected entries with public `/play/<feed-id>.pls` links, reported as UP in the directory. Deduplication by feed ID reduced 3,465 listings to 3,282 feeds. Offline entries without playback links are not included. The site's headline total of 4,441 is not the number of unique playable entries exposed by these pages.

The app retains the 14 previous defaults, including `kbos_twr`, which was absent from this online snapshot. This preserves existing saved selections and gives 3,283 total entries:

| Region | Feeds |
| --- | ---: |
| North America (including Central America and the Caribbean) | 2,745 |
| Europe | 281 |
| Oceania | 89 |
| Asia | 72 |
| South America | 72 |
| Africa | 5 |
| Oceanic / HF | 19 |

Directory categories are available through `feedindex.php?type=` with values `class-b`, `class-c`, `class-d`, `us-artcc`, `canada`, `international-eu`, `international-oc`, `international-as`, `international-sa`, `international-na`, `international-af`, and `hf`.

## Fields and playback

Feed IDs, channel names, airport identifiers, and locations come from the directory. Existing friendly names and stream URLs are preserved. IATA codes are carried forward for previously known airports; other entries use the source airport identifier for display. The optional `icao` field holds that source identifier, which can also be a local airport code or an HF identifier.

New stream URLs use the app's existing `https://s1-fmt2.liveatc.net/<feed-id>` convention with directory-sourced feed IDs. These relay addresses have not been individually resolved from every playlist or playback-tested. A directory UP status does not guarantee playback through this relay. The corresponding source playlist is `https://www.liveatc.net/play/<feed-id>.pls`; some feeds may require a different relay host. Existing host overrides are retained.

This is a bundled snapshot, not an automatic synchronization service. Feed availability, relay hosts, and directory contents can change. No audio recordings are bundled.
