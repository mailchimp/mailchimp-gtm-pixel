# mailchimp-gtm-pixel

A Google Tag Manager (GTM) **custom tag template** that loads the Mailchimp
Site Tracking pixel and configures it to run in GTM mode. It is a **thin
loader**: all GA4 → Mailchimp event mapping, payload building, identifier
capture and cart/checkout id persistence now live in the Mailchimp **pixel
reporting SDK** (activated via `referenceSystem: 'GTM'`), the same way the Wix
and Shopify integrations work.

This repository is structured for submission to the
[GTM Community Template Gallery](https://developers.google.com/tag-platform/tag-manager/templates/gallery).

## What the template does

The tag has exactly two responsibilities:

1. **Publishes its settings to `window.__mcGtmConfig`** so the SDK can read
   them. The published config is:
   - `userId` / `connectedSiteId` — the per-account pixel identifiers.
   - `captureGaClientId` / `captureEmail` / `capturePhone` — identifier capture
     flags.
   - `customEventMappings` — your custom dataLayer-event-name → Mailchimp-event
     rows (see [Custom event mappings](#custom-event-mappings)).
   Existing keys on `window.__mcGtmConfig` are preserved (merged, not replaced).
2. **Injects the per-account Mailchimp pixel SDK** directly
   (`https://chimpstatic.com/mcjs-connected/js/users/<userId>/<connectedSiteId>.js`).
   The injection uses the `mailchimp_pixel` cache token, so the SDK loads only
   once even if the tag fires repeatedly. There is no separate "bridge" shim —
   the SDK does its own tracking, so the old `window.mcTrack` / `window.mcIdentify`
   wrappers are gone.

Everything else — reading the GA4 `dataLayer`, translating ecommerce events
into Mailchimp events, hashing identifiers, generating/persisting
`cart_id` / `checkout_id`, and waiting for the pixel to be ready — is owned by
the SDK. Because the SDK reads the `dataLayer` itself, **the tag fires once on a
single Initialization / All Pages trigger** and no per-event triggers are
required.

### SDK contract

- The template only writes `window.__mcGtmConfig` (before injecting the script,
  so the SDK can read it while booting) and injects the per-account SDK loader.
- That loader must initialize the pixel in GTM mode —
  `pixel.init({ referenceSystem: 'GTM' })` — reading `window.__mcGtmConfig`.
  This is the one piece that lives server-side (in the per-account `mcjs`
  bootstrap), not in this template: a GTM custom template can only set globals
  and inject scripts; it cannot call `pixel.init()` itself.
- Once in GTM mode, the SDK reads `window.__mcGtmConfig` for its settings and
  starts its GTM integration: it attaches to the GA4 `dataLayer` (replaying
  history and patching `push`), translates the built-in GA4 ecommerce events
  (`view_item`, `select_item`, `view_item_list`, `add_to_cart`,
  `remove_from_cart`, `view_cart`, `begin_checkout`, `purchase`, `search`,
  `add_to_wishlist`, `add_payment_info`) into Mailchimp events, applies the
  `customEventMappings`, captures identifiers, and forwards everything through
  the standard track pipeline. Page views are emitted by the SDK's normal
  `autoTrack`, just like every other platform.

## Repository layout

The Gallery requires these files at the repo root, on `main`:

```
template.tpl       # GTM Custom Template (TAG, WEB) — exported from the editor
metadata.yaml      # Gallery metadata: homepage, documentation, versions
LICENSE            # Apache 2.0 (required by the Gallery)
README.md          # This file
```

## Installing in GTM (manual import)

1. In your GTM container, go to **Templates → Tag Templates → New**.
2. In the template editor, choose **⋮ → Import**.
3. Select `template.tpl` from this repo.
4. Save the template.
5. Create a new tag using the template and fill in:
   - **Mailchimp User ID** (`mcUserId`)
   - **Mailchimp Connected Site ID** (`mcConnectedSiteId`)
   - Toggle the identifier checkboxes you want enabled.
   - (Optional) Add **Custom event mappings** rows to forward your own
     dataLayer event names — see [Custom event mappings](#custom-event-mappings).
6. Add a single trigger:
   - An **Initialization — All Pages** trigger. That's all that's needed — the
     SDK reads the `dataLayer` itself, so you do **not** add per-event triggers.
     (Custom event names from the Custom event mappings table are handled by the
     SDK from the dataLayer; they don't need GTM triggers either.)

## Custom event mappings

Some sites don't fire the GA4-standard event names (for example a storefront
that pushes `addToCart` instead of `add_to_cart`). The **Custom event mappings**
table lets you map any dataLayer event name to a Mailchimp event without code
changes. Each row has:

- **Your dataLayer event name** — the `event` string your site pushes
  (e.g. `addToCart`).
- **Mailchimp event** — the target, chosen from: `PRODUCT_VIEWED`,
  `PRODUCT_CATEGORY_VIEWED`, `PRODUCT_ADDED_TO_CART`,
  `PRODUCT_REMOVED_FROM_CART`, `PRODUCT_ADDED_TO_WISHLIST`, `CART_VIEWED`,
  `CHECKOUT_STARTED`, `CHECKOUT_COMPLETED`, `PURCHASED`,
  `PAYMENT_INFO_SUBMITTED`, `SEARCH_SUBMITTED`, `PAGE_VIEWED`.

Behavior:

- Custom rows are **added on top of** the built-in GA4 mappings; the defaults
  keep working out of the box.
- Resolution is **fire-all, no dedup**: if a single event name resolves to more
  than one Mailchimp event (e.g. you map `add_to_cart` to a second target, or
  add a row that duplicates a built-in), every resolved mapping fires as its own
  Mailchimp event. A site that fires *only* `addToCart` (never `add_to_cart`)
  never double-fires, since the built-in name simply won't match.
- The custom event must still push GA4-shaped `ecommerce` data (and, for
  `SEARCH_SUBMITTED`, the top-level `search_term`); only the event **name** is
  remapped — all payload parsing is reused unchanged.
- These rows are passed to the SDK via `window.__mcGtmConfig.customEventMappings`
  and resolved by the SDK from the `dataLayer`. You do **not** need to add a GTM
  trigger for your custom event name.

## Required dataLayer shape

You push standard GA4 ecommerce events to the `dataLayer` exactly as you would
for GA4 — the **SDK** reads `event`, `ecommerce`, (optionally) `user_data`, and
`search_term` (only for `search` / `SEARCH_SUBMITTED`) directly. The template
itself does not read the dataLayer. Standard GA4 ecommerce events work as-is,
for example:

`ecommerce.cart_id` and `ecommerce.checkout_id` are optional — if present they
are used as-is, otherwise the SDK generates and persists its own ids in
`localStorage`.

```js
window.dataLayer = window.dataLayer || [];
dataLayer.push({ ecommerce: null });
dataLayer.push({
  event: 'purchase',
  ecommerce: {
    transaction_id: 'tx-123',
    value: 59.98,
    tax: 4.50,
    shipping: 5.00,
    currency: 'USD',
    items: [
      { item_id: 'sku-1', item_name: 'Hat', price: 29.99, quantity: 2 }
    ]
  },
  user_data: {
    email: 'shopper@example.com',
    phone_number: '+1 (555) 123-4567'
  }
});
```

## GTM Permissions used

| Permission       | Scope                                                                 |
| ---------------- | --------------------------------------------------------------------- |
| `logging`        | Debug environment only                                                |
| `access_globals` | `__mcGtmConfig` (read/write)                                           |
| `inject_script`  | `https://chimpstatic.com/mcjs-connected/js/users/*`                   |

Cookie access, dataLayer reads, and `localStorage` are no longer requested by
the template — those operations now happen inside the pixel SDK that the
template injects. The `inject_script` scope uses a `*` wildcard because the SDK
URL embeds the per-account `userId` / `connectedSiteId`.

## Categories

The Gallery `INFO` block declares the following categories (most → least
relevant):

1. `ANALYTICS`
2. `EMAIL_MARKETING`
3. `MARKETING`

## Development

The `.tpl` file is GTM's custom-template format with sections delimited by
`___SECTION___` markers. To iterate:

1. Open `template.tpl` in GTM's template editor (or any editor — it's plain
   text).
2. Edit the `___SANDBOXED_JS_FOR_WEB_TEMPLATE___` block for runtime
   behavior.
3. Edit `___TEMPLATE_PARAMETERS___` for the tag UI.
4. Edit `___WEB_PERMISSIONS___` when adding new APIs (each new `require(...)`
   typically needs a matching permission).
5. Add/adjust scenarios under `___TESTS___`. They run inside GTM's template
   sandbox via **Run tests** in the template editor.

## Tests

`___TESTS___` runs the template via `runCode(...)` with mocked sandbox APIs and
covers the thin loader's behavior:

- Missing `mcUserId` or `mcConnectedSiteId` fails the tag (`gtmOnFailure`) and
  does not inject the SDK.
- Valid ids publish `window.__mcGtmConfig` with `userId`, `connectedSiteId`, the
  capture flags and `customEventMappings`, and inject the per-account SDK from
  the expected URL with the `mailchimp_pixel` cache token, then call
  `gtmOnSuccess`.
- Existing `__mcGtmConfig` keys are preserved (merge, not replace).
- An SDK load failure propagates to `gtmOnFailure`.
- `customEventMappings` rows pass through to the SDK config untouched.

The GA4 → Mailchimp mapping, payload builder and identifier tests now live with
the SDK (`pixel-reporting-sdk`), since that's where the logic moved.

Run them from inside the GTM template editor via **Run tests**.

## Submitting / updating the Gallery entry

The Gallery key is `metadata.yaml`. Every published version is listed under
`versions:` (newest first) with the SHA of the commit that contains the
final `template.tpl` for that version.

To publish an update:

1. Land your `template.tpl` changes on `main`.
2. Copy the commit SHA of that landing commit.
3. Prepend a new entry to the top of `versions:` in `metadata.yaml`:
   ```yaml
   versions:
     - sha: <new-commit-sha>
       changeNotes: |2
         Short summary of what changed.
     # …older versions follow…
   ```
4. Commit and push. The Gallery picks up the change within a few days.

## Customer testing

For a step-by-step guide to testing this template with a customer (extracting
the User ID / Connected Site ID from the existing pixel snippet, importing
the template, smoke-testing in GTM Preview, and verifying events in
Mailchimp), see [`docs/CUSTOMER_TESTING.md`](./docs/CUSTOMER_TESTING.md).

## License

Apache License 2.0 — see [`LICENSE`](./LICENSE).
