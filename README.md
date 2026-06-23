# mailchimp-gtm-pixel

A Google Tag Manager (GTM) **custom tag template** that loads the Mailchimp
Site Tracking pixel and translates standard GA4 ecommerce `dataLayer` events
into Mailchimp's tracking schema.

This repository is structured for submission to the
[GTM Community Template Gallery](https://developers.google.com/tag-platform/tag-manager/templates/gallery).

The template:

- Loads `https://chimpstatic.com/mcjs-connected/bridge/v1/gtm-bridge.js`
  (a tiny shim that exposes `window.mcTrack` and `window.mcIdentify`).
- Maps GA4 ecommerce events → Mailchimp events:
  - `view_item` → `PRODUCT_VIEWED`
  - `add_to_cart` → `PRODUCT_ADDED_TO_CART`
  - `begin_checkout` → `CHECKOUT_STARTED`
  - `purchase` → `PURCHASED`
- Optionally sends identifiers to Mailchimp:
  - GA `_ga` client id as `GOOGLE_CLIENT_ID`
  - SHA-256 of the normalized email as `EMAIL_SHA256`
  - SHA-256 of the E.164-normalized phone as `PHONE_SHA256`

## Repository layout

The Gallery requires these three files at the repo root, on `main`:

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
6. Add triggers:
   - An **Initialization — All Pages** trigger (warms up the bridge on
     `gtm.js` / `gtm.dom` / `gtm.load`).
   - A custom event trigger for each ecommerce event you want to forward
     (`view_item`, `add_to_cart`, `begin_checkout`, `purchase`).

## Required dataLayer shape

The template reads three keys from the dataLayer: `event`, `ecommerce`, and
(optionally) `user_data`. Standard GA4 ecommerce events work as-is, for
example:

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
| `access_globals` | `mcTrack` (r/w/x), `mcIdentify` (r/w/x), `__mcGtmConfig` (r/w)        |
| `get_cookies`    | `_ga`                                                                 |
| `read_data_layer`| `event`, `ecommerce`, `user_data`                                     |
| `inject_script`  | `https://chimpstatic.com/mcjs-connected/bridge/v1/gtm-bridge.js`      |

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
- Cart-id fallback
- Line-item mapping, including missing-price → `0` (no `NaN`)
- ID validation
- Full payload shape for `PRODUCT_VIEWED`, `PRODUCT_ADDED_TO_CART`,
  `CHECKOUT_STARTED`, `PURCHASED` (with and without tax/shipping)
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
