# mailchimp-gtm-pixel

A Google Tag Manager (GTM) **custom tag template** that loads the Mailchimp
Site Tracking pixel and translates standard GA4 ecommerce `dataLayer` events
into Mailchimp's tracking schema.

This repository is structured for submission to the
[GTM Community Template Gallery](https://developers.google.com/tag-platform/tag-manager/templates/gallery).

The template:

- Loads `https://chimpstatic.com/mcjs-connected/bridge/v2/gtm-bridge.js`
  (a tiny shim that exposes `window.mcTrack` and `window.mcIdentify`).
- Defers every `track`/`identify` until the pixel is initialized. The bridge
  pushes `{ event: 'mailchimp.pixel.ready', mcPixelReady: true }` to the
  dataLayer once the Mailchimp SDK has finished loading, and the tag waits for
  that `mcPixelReady` signal (via `callLater`, bounded to 30s) before sending —
  so events captured before the pixel is ready aren't dropped.
- Maps GA4 ecommerce events → Mailchimp events (built-in defaults):
  - `view_item` → `PRODUCT_VIEWED`
  - `select_item` → `PRODUCT_VIEWED`
  - `view_item_list` → `PRODUCT_CATEGORY_VIEWED` (uses `item_list_id` /
    `item_list_name`, falling back to the first item's list fields / `item_category`)
  - `add_to_cart` → `PRODUCT_ADDED_TO_CART`
  - `remove_from_cart` → `PRODUCT_REMOVED_FROM_CART`
  - `view_cart` → `CART_VIEWED`
  - `begin_checkout` → `CHECKOUT_STARTED`
  - `purchase` → `PURCHASED`
  - `search` → `SEARCH_SUBMITTED` (reads the top-level GA4 `search_term`)
  - `add_to_wishlist` → `PRODUCT_ADDED_TO_WISHLIST`
  - `add_payment_info` → `PAYMENT_INFO_SUBMITTED`
  - `page_view` → `PAGE_VIEWED`
- Lets you map **your own** dataLayer event names to Mailchimp events via the
  **Custom event mappings** table (e.g. a site that fires `addToCart` instead of
  GA4's `add_to_cart`). See [Custom event mappings](#custom-event-mappings)
  below. Your custom event must still push GA4-shaped `ecommerce` data; only the
  event name is remapped. `CHECKOUT_COMPLETED` is available as a mapping target
  here (it has no GA4 default, since GA4 only emits `purchase`).
- Optionally sends identifiers to Mailchimp:
  - GA `_ga` client id as `GOOGLE_CLIENT_ID`
  - SHA-256 of the normalized email as `EMAIL_SHA256`
  - SHA-256 of the E.164-normalized phone as `PHONE_SHA256`
- Generates and persists `cart_id` / `checkout_id` in `localStorage` when the
  dataLayer doesn't provide them, so cart/checkout events are never dropped.
  The same ids are reused across the session and cleared on `purchase`.

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
6. Add triggers:
   - An **Initialization — All Pages** trigger (warms up the bridge on
     `gtm.js` / `gtm.dom` / `gtm.load`).
   - A custom event trigger for each event you want to forward — any built-in
     GA4 name (`view_item`, `select_item`, `view_item_list`, `add_to_cart`,
     `remove_from_cart`, `view_cart`, `begin_checkout`, `purchase`, `search`,
     `add_to_wishlist`, `add_payment_info`, `page_view`) **and** any custom
     event name you added to the Custom event mappings table.

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
- Don't forget to add a GTM **trigger** for your custom event name, otherwise
  the tag never fires for it.

## Required dataLayer shape

For the payload, the template reads from the dataLayer: `event`, `ecommerce`,
(optionally) `user_data`, and `search_term` (only for `search` /
`SEARCH_SUBMITTED`). (It also reads the bridge-owned `mcPixelReady` readiness
signal, which you don't set yourself.) Standard GA4 ecommerce events work as-is,
for example:

`ecommerce.cart_id` and `ecommerce.checkout_id` are optional — if present they
are used as-is, otherwise the template generates and persists its own ids in
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
| `access_globals` | `mcTrack` (r/w/x), `mcIdentify` (r/w/x), `__mcGtmConfig` (r/w)         |
| `get_cookies`    | `_ga`                                                                 |
| `read_data_layer`| `event`, `ecommerce`, `user_data`, `mcPixelReady`, `search_term`      |
| `inject_script`  | `https://chimpstatic.com/mcjs-connected/bridge/v2/gtm-bridge.js`      |
| `access_local_storage` | `mc_cart_id` (r/w), `mc_checkout_id` (r/w)                       |

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

`___TESTS___` covers:

- Bridge URL constant
- `_ga` cookie → GA client id parsing
- Email lowercasing/trimming
- Phone E.164 digit-stripping
- GA4 → Mailchimp event-name mapping (including unknown events)
- Built-in defaults for the newer events (`search` → `SEARCH_SUBMITTED`,
  `add_to_wishlist` → `PRODUCT_ADDED_TO_WISHLIST`, `add_payment_info` →
  `PAYMENT_INFO_SUBMITTED`, `page_view` → `PAGE_VIEWED`)
- Custom event mappings: resolving a non-GA4 name, appending to a built-in name
  and firing all (no dedup), and skipping rows with a missing name/event
- New payload builders: `SEARCH_SUBMITTED` (from `search_term`),
  `PRODUCT_ADDED_TO_WISHLIST`, `PAYMENT_INFO_SUBMITTED`, `CHECKOUT_COMPLETED`,
  and the base-only `PAGE_VIEWED`
- `cart_id` / `checkout_id` generated and persisted when missing (and used
  as-is when provided)
- Line-item mapping (`id` / `title` / `price` required; items with a
  missing/invalid/negative price are rejected, never coerced — no `NaN`)
- ID/price validation (`isValidPrice` rejects `NaN` and negatives)
- Full payload shape for `PRODUCT_VIEWED`, `PRODUCT_ADDED_TO_CART`,
  `CHECKOUT_STARTED`, `PURCHASED` (with and without tax/shipping)
- New mappings: `view_item_list` → `PRODUCT_CATEGORY_VIEWED` (with first-item
  fallback and the no-category failure case), `view_cart` → `CART_VIEWED`
  (including the lenient skip-invalid-items path), `select_item` →
  `PRODUCT_VIEWED`, and `remove_from_cart` → `PRODUCT_REMOVED_FROM_CART`
- Init-event recognition (`gtm.js` / `gtm.dom` / `gtm.load`)
- `__mcGtmConfig` merge preserves pre-existing keys

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
