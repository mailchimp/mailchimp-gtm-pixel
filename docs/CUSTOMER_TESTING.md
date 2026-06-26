# Customer testing guide — Mailchimp GTM Pixel Template

This guide walks a customer through testing the **Mailchimp Site Tracking
Pixel GTM template** end-to-end on their own site, before the template is
generally available in the [GTM Community Template Gallery](https://tagmanager.google.com/gallery/).

> **TL;DR**
> Today the template is **not yet in the Gallery**, so customers cannot search
> for it inside GTM. They must (1) install the existing Mailchimp Site
> Tracking pixel snippet on the page once to read their **User ID** and
> **Connected Site ID** out of the snippet URL, (2) import `template.tpl`
> from this repo into their GTM container as a custom template, (3) paste
> those two IDs into the tag, and (4) verify events arrive in Mailchimp.

---

## 1. Prerequisites

Before the customer starts, confirm they have:

| Item | Notes |
| --- | --- |
| A Mailchimp account with an active **Connected Site** | Found under **Audience → Website → Connected sites**. |
| Admin access to a **GTM container** on the test site | Needed to import a custom template and publish a workspace version. |
| A site that pushes **GA4 ecommerce events** to `dataLayer` | `view_item`, `add_to_cart`, `begin_checkout`, `purchase`. The template ignores everything else. If the site doesn't push GA4 events yet, that work is a prerequisite, not part of this test. |
| Ability to install the existing Mailchimp Site Tracking snippet **once**, even briefly | Only used to extract the two IDs. Can be removed immediately after. |
| A browser with the [Tag Assistant Companion](https://chrome.google.com/webstore/detail/tag-assistant-companion/jmekfmbnaedfebfnmakmokmlfpblbfdm) extension | For GTM Preview mode. |

---

## 2. Get the two IDs from the existing pixel snippet

The Mailchimp Site Tracking pixel snippet looks like this (the customer can
copy it from **Audience → Website → Connected sites → View code**):

```html
<script id="mcjs">!function(c,h,i,m,p){m=c.createElement(h),p=c.getElementsByTagName(h)[0],m.async=1,m.src=i,p.parentNode.insertBefore(m,p)}(document,"script","https://chimpstatic.com/mcjs-connected/<USER_ID>/<CONNECTED_SITE_ID>.js");</script>
```

The two values we need are embedded in the script URL:

```
https://chimpstatic.com/mcjs-connected/<USER_ID>/<CONNECTED_SITE_ID>.js
                                       └────┬────┘ └─────────┬────────┘
                                            │                │
                                  Mailchimp User ID      Connected Site ID
                                  (numeric, e.g. 1234567)  (hex, e.g. a1b2c3d4e5f6...)
```

**Action:** Copy each value out of the URL. Both are required by the GTM
template (`mcUserId` and `mcConnectedSiteId`).

> **Note:** The customer **does not need to keep the snippet installed** for
> the GTM template to work. The template injects the per-account Mailchimp
> pixel SDK (`chimpstatic.com/mcjs-connected/js/users/<userId>/<connectedSiteId>.js`)
> and uses these two IDs to attribute events. If the snippet is left in place
> alongside the GTM tag, the customer may see double-tracking — remove the
> snippet before going live.

---

## 3. Import the template into GTM

1. In the GTM container, go to **Templates → Tag Templates → New**.
2. Click the overflow menu (**⋮**) in the editor and choose **Import**.
3. Select `template.tpl` from this repository.
4. Click **Save**. The template should appear in the Tag Templates list as
   **Mailchimp Site Tracking Pixel**.

If `template.tpl` is not handy, customers can download it directly from this
repo's `template.tpl` at the root.

---

## 4. Create the tag

1. **Tags → New → Tag Configuration →** *Mailchimp Site Tracking Pixel*.
2. Fill in:
   - **Mailchimp User ID** → paste `<USER_ID>` from step 2.
   - **Mailchimp Connected Site ID** → paste `<CONNECTED_SITE_ID>` from step 2.
   - **Capture Google Analytics Client ID** → ✅ (recommended).
   - **Capture and hash email (EMAIL_SHA256)** → ✅ if the site exposes
     `user_data.email` on the dataLayer.
   - **Capture and hash phone (PHONE_SHA256)** → ✅ if the site exposes
     `user_data.phone_number` on the dataLayer.
3. **Triggering →** add a **single** trigger:

   | Trigger | Type | Fires on |
   | --- | --- | --- |
   | `MC – Init` | **Initialization — All Pages** | `gtm.js` / `gtm.dom` / `gtm.load` |

   > **No per-event triggers are required.** The tag fires once to inject the
   > SDK; the SDK then reads the GA4 `dataLayer` itself (replaying history and
   > intercepting future `push`es) and translates ecommerce events on its own.
   > Adding custom-event triggers for `view_item`, `add_to_cart`, etc. is
   > unnecessary and would only re-inject the (cached) SDK.

4. Name the tag `Mailchimp – Site Tracking` and **Save**.

---

## 5. Smoke test in GTM Preview mode

1. Click **Preview** in GTM and enter the test site URL.
2. In Tag Assistant, walk through the funnel on the test site:
   - Load a product page → expect `view_item` to fire.
   - Add to cart → expect `add_to_cart`.
   - Start checkout → expect `begin_checkout`.
   - Complete a (sandbox) purchase → expect `purchase`.
3. In the Tag Assistant left-hand event list, click each ecommerce event and
   confirm:

   | Check | Pass criteria |
   | --- | --- |
   | The `Mailchimp – Site Tracking` tag shows under **Tags Fired** on the Initialization event | ✅ |
   | DevTools → **Network** shows a request to `chimpstatic.com/mcjs-connected/js/users/<userId>/<connectedSiteId>.js` (loaded **once** on Init, then cached) | ✅ |
   | DevTools → **Network** shows beacons to Mailchimp (`me-1.mailchimp.com` or `*.list-manage.com`) after each ecommerce event | ✅ |

If any of these fail, jump to **Section 8 – Troubleshooting**.

---

## 6. Verify events in Mailchimp

Mailchimp surfaces incoming pixel data in a few places. Events can take **a
few minutes** to appear (sometimes longer for first-time setup).

1. **Audience → Website → Connected sites → \<site\>** — page-view counts and
   recent activity should increment.
2. **Audience → Contacts → \<contact\>** — if `EMAIL_SHA256` is enabled and
   the email matches a known contact, the contact's **Activity** feed should
   show product views, cart adds, checkout starts, and orders.
3. **Audience → Insights → Activity feed** — top-level stream of all events
   coming from the site.

For each of the four GA4 events you exercised in step 5, confirm the
corresponding Mailchimp event appears:

| GA4 event | Mailchimp event |
| --- | --- |
| `view_item` | `PRODUCT_VIEWED` |
| `add_to_cart` | `PRODUCT_ADDED_TO_CART` |
| `begin_checkout` | `CHECKOUT_STARTED` |
| `purchase` | `PURCHASED` |

---

## 7. Test data the customer can paste

If the customer's site doesn't have a working ecommerce funnel in the test
environment, they can paste the following into the browser console on any
page where the GTM container is loaded. Each block fires one Mailchimp event.

```js
// Reset ecommerce object before each push (GA4 best practice)
window.dataLayer = window.dataLayer || [];

// view_item → PRODUCT_VIEWED
dataLayer.push({ ecommerce: null });
dataLayer.push({
  event: 'view_item',
  ecommerce: {
    currency: 'USD',
    value: 29.99,
    items: [{ item_id: 'sku-1', item_name: 'Test Hat', price: 29.99, quantity: 1 }]
  },
  user_data: { email: 'test+gtm@example.com' }
});

// add_to_cart → PRODUCT_ADDED_TO_CART
dataLayer.push({ ecommerce: null });
dataLayer.push({
  event: 'add_to_cart',
  ecommerce: {
    currency: 'USD',
    value: 59.98,
    items: [{ item_id: 'sku-1', item_name: 'Test Hat', price: 29.99, quantity: 2 }]
  },
  user_data: { email: 'test+gtm@example.com' }
});

// begin_checkout → CHECKOUT_STARTED
dataLayer.push({ ecommerce: null });
dataLayer.push({
  event: 'begin_checkout',
  ecommerce: {
    currency: 'USD',
    value: 59.98,
    items: [{ item_id: 'sku-1', item_name: 'Test Hat', price: 29.99, quantity: 2 }]
  },
  user_data: { email: 'test+gtm@example.com' }
});

// purchase → PURCHASED
dataLayer.push({ ecommerce: null });
dataLayer.push({
  event: 'purchase',
  ecommerce: {
    transaction_id: 'tx-test-' + Date.now(),
    currency: 'USD',
    value: 64.98,
    tax: 4.50,
    shipping: 5.00,
    items: [{ item_id: 'sku-1', item_name: 'Test Hat', price: 29.99, quantity: 2 }]
  },
  user_data: { email: 'test+gtm@example.com', phone_number: '+1 (555) 123-4567' }
});
```

Use a **unique `transaction_id`** for each purchase test (the `Date.now()`
suffix above handles that). Mailchimp deduplicates orders by transaction ID
and silently drops repeats.

---

## 8. Troubleshooting

| Symptom | Likely cause | Fix |
| --- | --- | --- |
| Tag does not fire in Preview | Missing Initialization trigger | Re-check that the tag has the **Initialization — All Pages** trigger attached. |
| Ecommerce events don't reach Mailchimp even though the tag fired | The SDK couldn't read the GA4 `dataLayer` | Confirm the site actually pushes GA4 ecommerce events (`view_item`, `add_to_cart`, …) to `window.dataLayer`. The SDK only translates events that GA4 emits. |
| Tag fires but Console shows `Mailchimp Error: Missing User ID or Connected Site ID` | Empty or wrong IDs in the tag config | Re-copy from the snippet URL. **No quotes**, no whitespace. The User ID is numeric; the Connected Site ID is a long hex string. |
| The pixel SDK doesn't load (404 / blocked in Network tab) | Content Security Policy on the customer site blocks `chimpstatic.com` | Add `https://chimpstatic.com` to the site's CSP `script-src` directive. |
| Tag fires, no errors, but nothing appears in Mailchimp | Wrong Connected Site ID, or events going to a different audience | Verify the IDs against **Audience → Website → Connected sites → View code** for the *exact* audience you're checking. |
| Duplicate events in Mailchimp | The old snippet is still installed alongside the GTM tag | Remove the `<script id="mcjs">` snippet from the site source; keep only the GTM tag. |
| `purchase` doesn't appear, but other events do | Same `transaction_id` reused across tests | Use a new ID per test (e.g. `tx-test-<timestamp>`). |
| `EMAIL_SHA256` / `PHONE_SHA256` not appearing | Identifier checkbox unchecked, or `user_data` not in the dataLayer push | Tick the checkbox in the tag config **and** confirm the site (or the test snippet above) actually pushes `user_data.email` / `user_data.phone_number`. |
| Events fire on initial pageload but not on subsequent SPA route changes | SPA isn't pushing GA4 events on virtual page transitions | Out of scope for this template — fix the site's GA4 instrumentation first. |

To pull more detailed logs, enable **Preview mode** in GTM and watch the
browser console — the template logs ID-validation errors through GTM's
`logging` permission (debug-only). Once the SDK is loaded, event-level
diagnostics come from the pixel SDK itself, not the template.

---

## 9. Customer sign-off checklist

Before declaring the test successful and handing off, confirm all of the
following with the customer:

- [ ] `Mailchimp – Site Tracking` tag fires in GTM Preview on the
      **Initialization** event.
- [ ] The per-account pixel SDK
      (`chimpstatic.com/mcjs-connected/js/users/<userId>/<connectedSiteId>.js`)
      loads exactly once per pageview (Network tab).
- [ ] Mailchimp's **Audience → Contacts** activity feed shows the test
      contact with `PRODUCT_VIEWED`, `PRODUCT_ADDED_TO_CART`,
      `CHECKOUT_STARTED`, and `PURCHASED` events with the expected
      product / price / currency.
- [ ] The pre-existing `<script id="mcjs">` snippet has been removed from
      the site (or scheduled for removal at cutover).
- [ ] The GTM workspace containing the new tag has been **published** (not
      just saved in the workspace).
- [ ] A follow-up date is on the calendar to recheck Mailchimp activity 24h
      after cutover, to confirm steady-state event volume.

---

## 10. Reporting issues

If something doesn't behave as documented, capture and share:

1. The **GTM container ID** and the workspace version under test.
2. A screenshot of the **Tag Assistant** event list showing the failing
   event.
3. Browser **DevTools → Network** HAR for the failing pageview (filtered to
   `chimpstatic` and `mailchimp`).
4. Browser **DevTools → Console** log filtered to lines starting with
   `MC ` / `Mailchimp `.
5. The exact **Mailchimp User ID** and **Connected Site ID** used (these
   are not secret; both are exposed in the public pixel snippet).

File these as a new GitHub issue on this repo, or send to the Mailchimp
integrations contact who provisioned the template for the customer.
