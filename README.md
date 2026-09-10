# Mailchimp Site Tracking Pixel — Google Tag Manager template

A [Google Tag Manager](https://tagmanager.google.com/) custom tag template that
loads the **Mailchimp Site Tracking pixel** and forwards your site's GA4
ecommerce events to Mailchimp — no extra code on your site.

If you already send standard GA4 ecommerce events to the GTM `dataLayer`
(`view_item`, `add_to_cart`, `begin_checkout`, `purchase`, …), this template
turns them into the matching Mailchimp events automatically.

## What it does

You add the tag once and give it your Mailchimp snippet URL. From then on:

- Standard GA4 ecommerce events are translated into Mailchimp events
  (for example `add_to_cart` → `PRODUCT_ADDED_TO_CART`, `purchase` → `PURCHASED`).
- The Google Analytics client ID is captured when you enable **Capture Google
  Analytics Client ID** (see [Capturing the GA client ID](#capturing-the-ga-client-id)),
  and sent to Mailchimp as a `GOOGLE_CLIENT_ID` identifier used to link a visitor
  across sessions during identity resolution.
- Optional hashed identifiers (email, phone) are captured when you enable them.
- Your own custom event names can be mapped to Mailchimp events without any code
  changes (see [Custom event mappings](#custom-event-mappings)).

The tag itself is a thin loader: it injects the Mailchimp pixel SDK and the SDK
does all the work. Because the SDK reads the `dataLayer` directly, **the tag only
needs a single All Pages (Page View) trigger** — you do not add per-event or
ecommerce triggers.

## Before you start

You'll need:

- A Mailchimp account with the **Site Tracking integration** set up
  (**Mailchimp → Integrations**).
- Admin access to a **GTM container** on your website.
- A site that already pushes **GA4 ecommerce events** to `window.dataLayer`.

## Installation

### 1. Get your Mailchimp snippet URL

In Mailchimp, go to **Integrations** and open your site integration. You'll see a
snippet like this:

```html
<script id="mcjs">!function(c,h,i,m,p){m=c.createElement(h),p=c.getElementsByTagName(h)[0],m.async=1,m.src=i,p.parentNode.insertBefore(m,p)}(document,"script","https://chimpstatic.com/mcjs-connected/js/users/<USER_ID>/<CONNECTED_SITE_ID>.js");</script>
```

Copy just the URL from inside the script tag — the
`https://chimpstatic.com/mcjs-connected/js/users/…/….js` part. That single URL
is all the template needs.

> You do **not** need to keep the raw snippet on your site. If you leave it
> installed alongside the GTM tag you may see double-tracking, so remove it
> before going live.

### 2. Add the template from the Community Template Gallery

1. In your GTM container, go to **Templates → Tag Templates → Search Gallery**.
2. Search for **Mailchimp** and select **Mailchimp Site Tracking Pixel**.
3. Click **Add to workspace**.

> Prefer a manual install? You can also import `template.tpl` from this
> repository via **Tag Templates → New → ⋮ → Import**.

### 3. Create and trigger the tag

1. Go to **Tags → New → Tag Configuration → Mailchimp Site Tracking Pixel**.
2. Fill in:
   - **Mailchimp snippet URL** — the URL you copied in step 1.
   - **Capture Google Analytics Client ID** — enable to capture the GA4 client ID
     as a `GOOGLE_CLIENT_ID` identifier (see
     [Capturing the GA client ID](#capturing-the-ga-client-id)). On by default;
     uncheck to skip it.
   - **GA4 Measurement ID** — your `G-XXXXXXXXXX`. **Required** when capturing the
     client ID (see [Capturing the GA client ID](#capturing-the-ga-client-id)).
   - **Capture and hash email (EMAIL_SHA256)** — enable if your site pushes
     `user_data.email` to the `dataLayer`, or you map a **User-Provided Data
     variable** (see below).
   - **Capture and hash phone (PHONE_SHA256)** — enable if your site pushes
     `user_data.phone_number` to the `dataLayer`, or you map a **User-Provided
     Data variable** (see below).
   - *(Optional)* **User-Provided Data variable** — see
     [Capturing user data](#capturing-user-data).
   - *(Optional)* **Custom event mappings** — see below.
   - **Read GA4 ecommerce events from the dataLayer** — enabled by default; the
     SDK reads `window.dataLayer` to translate ecommerce events and capture
     `user_data` identifiers pushed alongside them. Disable only if your site's
     policy prohibits third-party `dataLayer` access — **Capture Google
     Analytics Client ID** and the **User-Provided Data variable** above still
     work with this off, since neither touches `dataLayer`.
3. Add a single trigger: **All Pages** (Page View). That's all that's needed —
   no per-event or ecommerce triggers. The injected SDK reads the `dataLayer`
   itself and translates ecommerce events on its own.
4. Save, then **Submit / Publish** the container.

## Supported events

The template forwards these standard GA4 events out of the box:

| GA4 event          | Mailchimp event             |
| ------------------ | --------------------------- |
| `view_item`        | `PRODUCT_VIEWED`            |
| `view_item_list`   | `PRODUCT_CATEGORY_VIEWED`   |
| `select_item`      | `PRODUCT_VIEWED`            |
| `add_to_cart`      | `PRODUCT_ADDED_TO_CART`     |
| `remove_from_cart` | `PRODUCT_REMOVED_FROM_CART` |
| `add_to_wishlist`  | `PRODUCT_ADDED_TO_WISHLIST` |
| `view_cart`        | `CART_VIEWED`               |
| `begin_checkout`   | `CHECKOUT_STARTED`          |
| `add_payment_info` | `PAYMENT_INFO_SUBMITTED`    |
| `purchase`         | `PURCHASED`                 |
| `search`           | `SEARCH_SUBMITTED`          |

Page views are tracked automatically.

## Required dataLayer shape

Push standard GA4 ecommerce events exactly as you would for GA4. The SDK reads
`event`, `ecommerce`, (optionally) `user_data`, and `search_term` (for `search`)
directly:

```js
window.dataLayer = window.dataLayer || [];
dataLayer.push({ ecommerce: null }); // GA4 best practice: clear before each push
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

`ecommerce.cart_id` and `ecommerce.checkout_id` are optional. If present they're
used as-is; otherwise the SDK generates and persists its own IDs in
`localStorage`.

## Capturing the GA client ID

When **Capture Google Analytics Client ID** is enabled, the pixel reads the GA4
client ID via Google's `gtag('get', …)` API and sends it to Mailchimp as a
`GOOGLE_CLIENT_ID` identifier. Mailchimp uses it to link a visitor's activity
across sessions during identity resolution — it is longer-lived than the pixel's
own anonymous visitor ID, so it helps keep a contact resolvable over time.

- **Requirements** — your site must run GA4 on the page (gtag.js directly, or a
  GTM-managed Google tag) so `gtag` is available.
- **Measurement ID** — the pixel needs your GA4 Measurement ID (`G-XXXXXXXXXX`)
  to call `gtag('get', …)`, so you **must set the GA4 Measurement ID field
  explicitly** — there is no auto-detection. Find it in Google Analytics under
  **Admin → Data streams → your web stream**. A Google Tag ID (`GT-…`) will not
  work; use the `G-…` Measurement ID.
- **Consent-aware** — capture goes through `gtag`, so when GA Consent Mode denies
  analytics storage, `gtag` returns no client ID and nothing is captured. There
  is no cookie fallback.
- **Opt-in** — capture only happens when the checkbox is enabled. When it's off
  (or the config is absent), the pixel does not attempt to read the client ID.
- **Privacy** — the GA client ID is an online identifier (personal data under
  GDPR, personal information under CCPA/CPRA). Before enabling, make sure your
  site's privacy notice discloses this use and your consent flow covers it.

## Capturing user data

There are two ways to capture a customer's email/phone, both gated by the
**Capture and hash email/phone** checkboxes:

1. **From the `dataLayer`** — if your site pushes a `user_data` object alongside
   your events (as shown above), the SDK reads `user_data.email` /
   `user_data.phone_number` directly.

2. **From a GTM "User-Provided Data" variable** — in some setups the email/phone
   is collected **inside GTM** and **never reaches the `dataLayer`** — so the SDK
   can't see it. In that case, create or reuse a GTM **User-Provided Data**
   variable and map it into the tag's **User-Provided Data variable** field so
   GTM passes the value to the SDK.

   The variable must resolve to an object with `email` and/or `phone_number`:

   ```js
   { email: 'shopper@example.com', phone_number: '+1 (555) 123-4567' }
   ```

   GTM resolves the variable in the container when the tag fires and passes the
   value to the SDK, which **normalizes and SHA-256 hashes** it before sending
   (`EMAIL_SHA256` / `PHONE_SHA256`). Only the fields whose capture checkbox is
   enabled are forwarded. Provide **plaintext** values — the SDK does the
   hashing, so don't map an already-hashed variable.

## Custom event mappings

Some sites don't use the GA4-standard event names (for example a storefront that
pushes `addToCart` instead of `add_to_cart`). The **Custom event mappings** table
lets you map any `dataLayer` event name to a Mailchimp event without code
changes. Each row has:

- **Your dataLayer event name** — the `event` string your site pushes
  (e.g. `addToCart`).
- **Mailchimp event** — the target event to fire.

Notes:

- Custom rows are **added on top of** the built-in mappings; the defaults keep
  working.
- If one event name resolves to more than one Mailchimp event, each one fires.
- Your custom event must still push GA4-shaped `ecommerce` data (and, for
  `SEARCH_SUBMITTED`, a top-level `search_term`); only the event **name** is
  remapped.
- You do **not** need to add a GTM trigger for your custom event name — the SDK
  reads it from the `dataLayer`.

## Permissions used

| Permission       | Scope                                                |
| ---------------- | ---------------------------------------------------- |
| `logging`        | Debug environment only                               |
| `access_globals` | `__mcGtmConfig` (read/write)                         |
| `inject_script`  | `https://chimpstatic.com/mcjs-connected/js/users/*`  |

The template only writes its settings to `window.__mcGtmConfig` and injects the
Mailchimp pixel SDK from your snippet URL. Reading the `dataLayer`, hashing
identifiers, and `localStorage` access all happen inside the SDK, not the
template.

## Testing

The template's unit tests live in the `___TESTS___` section of `template.tpl`
and run inside the GTM template editor via **Run tests**.

To verify end-to-end, use GTM **Preview** mode: confirm the tag fires on page
load (the All Pages trigger), the pixel SDK loads once from your snippet URL
(Network tab), and your GA4 ecommerce events show up in Mailchimp (ecommerce
analytics, segmentation, and automations).

## License

Apache License 2.0 — see [`LICENSE`](./LICENSE).
