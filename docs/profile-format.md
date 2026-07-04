# Humation Profile JSON Format

`HumationProfile` is the stable JSON wire format for storing and sending a
humation avatar profile. It is compatible with the TypeScript humation
`HumationAvatarProfile` shape.

## Shape

```json
{
  "selections": {
    "head": "hm1-p-000001",
    "body": "hm1-p-000025",
    "bottom": "hm1-p-000033",
    "item": "hm1-p-000041",
    "glasses": "hm1-p-000056"
  },
  "colors": {
    "background": "F6F5F4",
    "stroke": "000000",
    "hair": "1C1C1E",
    "skin": "FFFFFF",
    "clothes": "FFFFFF",
    "bottom": "000000"
  }
}
```

Both top-level fields are always encoded. Empty profiles are encoded as empty
objects:

```json
{ "selections": {}, "colors": {} }
```

Every entry is optional. Missing selections are resolved from the supplied seed
when a seed is available, otherwise from manifest defaults. Missing colors are
resolved from manifest defaults.

## Selection Keys

Selection keys are `HumationSelectionSlot` raw values:

- `head`
- `body`
- `bottom`
- `item`
- `glasses`

Selection values are manifest part ids such as `hm1-p-000001`.

## Color Keys

Color keys are `HumationColorSlot` raw values:

- `background`
- `stroke`
- `hair`
- `skin`
- `clothes`
- `bottom`

Color values are normalized when decoded or initialized:

- Remove a leading `#`.
- Uppercase hexadecimal letters.
- Use six hexadecimal digits, for example `1C1C1E`.
- The literal `transparent` is allowed only for `background`.

## Forward Compatibility

Unknown selection or color keys must be ignored by decoders. This allows newer
asset packs or clients to add slots without breaking older clients.

Values must be strings. A decoder may reject non-string values instead of
silently ignoring them.

Encoders should only emit the known selection and color slot keys listed above.

## Healing

Profiles can outlive an asset pack revision. During resolution, an explicit
selection is treated as unspecified when either of these is true:

- The referenced part id does not exist in the manifest.
- The referenced part exists, but its `selectionSlot` does not match the profile
  key it was provided under.

After an invalid entry is ignored, normal fallback applies: use the seeded pick
when a seed is provided, otherwise use the manifest default. This ensures stale
profiles can still render safely after parts are removed or moved between slots.
