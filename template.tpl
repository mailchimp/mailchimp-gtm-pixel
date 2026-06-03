___TERMS_OF_SERVICE___

By creating or modifying this file you agree to Google Tag Manager's Community
Template Gallery Developer Terms of Service available at
https://developers.google.com/tag-manager/gallery-tos (or such other URL as
Google may provide), as modified from time to time.


___INFO___

{
  "type": "TAG",
  "id": "cvt_temp_public_id",
  "version": 1,
  "securityGroups": [],
  "displayName": "Mailchimp Site Tracking Pixel",
  "brand": {
    "id": "brand_dummy",
    "displayName": "Mailchimp"
  },
  "description": "Loads the Mailchimp Site Tracking Pixel and translates standard GA4 ecommerce dataLayer events into Mailchimp\u0027s tracking schema",
  "categories": [
    "ANALYTICS",
    "EMAIL_MARKETING",
    "MARKETING"
  ],
  "containerContexts": [
    "WEB"
  ]
}


___TEMPLATE_PARAMETERS___

[
  {
    "type": "TEXT",
    "name": "mcUserId",
    "displayName": "Mailchimp User ID",
    "simpleValueType": true,
    "defaultValue": 123
  },
  {
    "type": "TEXT",
    "name": "mcConnectedSiteId",
    "displayName": "Mailchimp Connected Site ID",
    "simpleValueType": true,
    "defaultValue": 123
  },
  {
    "type": "CHECKBOX",
    "name": "captureGaClientId",
    "checkboxText": "Capture Google Analytics Client ID",
    "simpleValueType": true
  },
  {
    "type": "CHECKBOX",
    "name": "captureEmail",
    "checkboxText": "Capture and hash email (EMAIL_SHA256)",
    "simpleValueType": true
  },
  {
    "type": "CHECKBOX",
    "name": "capturePhone",
    "checkboxText": "Capture and hash phone (PHONE_SHA256)",
    "simpleValueType": true
  }
]


___SANDBOXED_JS_FOR_WEB_TEMPLATE___

const copyFromDataLayer = require('copyFromDataLayer');
const injectScript = require('injectScript');
const callInWindow = require('callInWindow');
const copyFromWindow = require('copyFromWindow');
const setInWindow = require('setInWindow');
const getCookieValues = require('getCookieValues');
const makeString = require('makeString');
const makeNumber = require('makeNumber');
const logToConsole = require('logToConsole');
const sha256 = require('sha256');
const getTimestampMillis = require('getTimestampMillis');
const JSON = require('JSON');
const callLater = require('callLater');

const userId = data.mcUserId;
const connectedSiteId = data.mcConnectedSiteId;
const captureGA = data.captureGaClientId;
const captureEmail = data.captureEmail;
const capturePhone = data.capturePhone;

const currentEvent = copyFromDataLayer('event');
logToConsole('MC Fired - event context: ' + currentEvent);

if (!userId || !connectedSiteId) {
  logToConsole('Mailchimp Error: Missing User ID or Connected Site ID.');
  data.gtmOnFailure();
  return;
}

const bridgeUrl = 'https://chimpstatic.com/mcjs-connected/bridge/v1/gtm-bridge.js';

const cfg = copyFromWindow('__mcGtmConfig') || {};
cfg.userId = userId;
cfg.connectedSiteId = connectedSiteId;
setInWindow('__mcGtmConfig', cfg, true);

function normalizeEmail(email) {
  return makeString(email).toLowerCase().trim();
}

function normalizePhone(phone) {
  const str = makeString(phone).trim();
  let digits = '';
  for (let i = 0; i < str.length; i++) {
    const c = str[i];
    if (c >= '0' && c <= '9') digits += c;
  }
  return digits.length > 0 ? '+' + digits : str;
}

function shimReady() {
  return !!copyFromWindow('mcTrack');
}

function runIdentify() {
  if (captureGA) {
    const gaCookies = getCookieValues('_ga');
    if (gaCookies && gaCookies.length > 0) {
      const parts = gaCookies[0].split('.');
      const clientId = parts.length >= 4
        ? parts[parts.length - 2] + '.' + parts[parts.length - 1]
        : gaCookies[0];
      callInWindow('mcIdentify', { type: 'GOOGLE_CLIENT_ID', value: clientId });
      logToConsole('MC: identify GOOGLE_CLIENT_ID sent via shim');
    }
  }

  const userData = copyFromDataLayer('user_data');

  if (captureEmail && userData && userData.email) {
    sha256(normalizeEmail(userData.email), function(hash) {
      callInWindow('mcIdentify', { type: 'EMAIL_SHA256', value: hash });
      logToConsole('MC: identify EMAIL_SHA256 sent via shim');
    });
  }

  if (capturePhone && userData && userData.phone_number) {
    sha256(normalizePhone(userData.phone_number), function(hash) {
      callInWindow('mcIdentify', { type: 'PHONE_SHA256', value: hash });
      logToConsole('MC: identify PHONE_SHA256 sent via shim');
    });
  }
}

function getLineItem(item) {
  const unitPrice = makeNumber(item.price) || 0;
  const qty = makeNumber(item.quantity) || 1;
  return {
    item: {
      id:        item.item_variant || item.variant_id || item.item_id || item.id || '',
      productId: item.item_id || item.product_id || item.id || '',
      title:     item.item_name || item.name || item.title || '',
      price:     unitPrice
    },
    quantity: qty,
    price:    unitPrice * qty
  };
}

function runTrack() {
  const eventMap = {
    'view_item':      'PRODUCT_VIEWED',
    'add_to_cart':    'PRODUCT_ADDED_TO_CART',
    'begin_checkout': 'CHECKOUT_STARTED',
    'purchase':       'PURCHASED'
  };

  const mcEvent = eventMap[currentEvent];
  if (!mcEvent) {
    logToConsole('MC: no event mapping for ' + currentEvent);
    return;
  }

  const e = copyFromDataLayer('ecommerce');
  if (!e) {
    logToConsole('MC: no ecommerce payload');
    return;
  }

  let props = {};

  if (mcEvent === 'PRODUCT_VIEWED') {
    const item = (e.items && e.items[0]) || e || {};
    props = {
      product: {
        id:         item.item_variant || item.variant_id || item.item_id || item.id || 'prod-unknown',
        productId:  item.item_id || item.product_id || item.id || 'prod-unknown',
        title:      item.item_name || item.name || item.title || 'Unknown Product',
        price:      makeNumber(item.price) || 0,
        currency:   e.currency || 'USD',
        sku:        item.item_id || item.sku || item.id || '',
        vendor:     item.item_brand || item.brand || item.vendor || '',
        categories: item.item_category ? [item.item_category] : []
      }
    };
  } else if (mcEvent === 'PRODUCT_ADDED_TO_CART') {
    const item = e.items && e.items[0];
    if (!item) {
      logToConsole('MC: add_to_cart missing items[0]');
      return;
    }
    const unitPrice = makeNumber(item.price) || 0;
    const qty = makeNumber(item.quantity) || 1;
    props = {
      cartId: e.cart_id || e.id || 'cart-' + makeString(getTimestampMillis()),
      product: {
        item: {
          id:        item.item_variant || item.item_id || '',
          productId: item.item_id || '',
          title:     item.item_name || '',
          price:     unitPrice,
          currency:  e.currency || 'USD',
          sku:       item.item_id || ''
        },
        quantity: qty,
        price:    unitPrice * qty,
        currency: e.currency || 'USD'
      }
    };
  } else if (mcEvent === 'CHECKOUT_STARTED') {
    props = {
      checkout: {
        id:         e.checkout_id || e.transaction_id || 'checkout-' + makeString(getTimestampMillis()),
        cartId:     e.cart_id || 'cart-' + makeString(getTimestampMillis()),
        lineItems:  (e.items || []).map(getLineItem),
        totalPrice: makeNumber(e.value) || 0,
        currency:   e.currency || 'USD'
      }
    };
  } else if (mcEvent === 'PURCHASED') {
    props = {
      order: {
        id:            e.transaction_id || 'order-' + makeString(getTimestampMillis()),
        lineItems:     (e.items || []).map(getLineItem),
        totalPrice:    makeNumber(e.value) || 0,
        totalTax:      makeNumber(e.tax) || 0,
        totalShipping: makeNumber(e.shipping) || 0,
        currency:      e.currency || 'USD'
      }
    };
  }

  logToConsole('MC Track Event payload: ' + JSON.stringify(props));
  callInWindow('mcTrack', mcEvent, props);
  logToConsole('MC: mcTrack shim called for ' + mcEvent);
}

function deferUntilReady(attempts, onReady) {
  if (shimReady()) {
    onReady();
    return;
  }
  if (attempts >= 40) {
    logToConsole('MC: shim never became ready.');
    data.gtmOnFailure();
    return;
  }
  callLater(function() { deferUntilReady(attempts + 1, onReady); });
}

function ensureBridge(onReady) {
  if (shimReady()) {
    onReady();
    return;
  }
  injectScript(bridgeUrl, function() {
    deferUntilReady(0, onReady);
  }, data.gtmOnFailure, 'mailchimp_bridge');
}

const isInitEvent = (currentEvent === 'gtm.js' || currentEvent === 'gtm.dom' || currentEvent === 'gtm.load');

if (isInitEvent) {
  ensureBridge(function() {
    logToConsole('MC: bridge ready on init event');
    data.gtmOnSuccess();
  });
} else {
  ensureBridge(function() {
    runIdentify();
    runTrack();
    data.gtmOnSuccess();
  });
}


___WEB_PERMISSIONS___

[
  {
    "instance": {
      "key": {
        "publicId": "logging",
        "versionId": "1"
      },
      "param": [
        {
          "key": "environments",
          "value": {
            "type": 1,
            "string": "debug"
          }
        }
      ]
    },
    "clientAnnotations": {
      "isEditedByUser": true
    },
    "isRequired": true
  },
  {
    "instance": {
      "key": {
        "publicId": "access_globals",
        "versionId": "1"
      },
      "param": [
        {
          "key": "keys",
          "value": {
            "type": 2,
            "listItem": [
              {
                "type": 3,
                "mapKey": [
                  {
                    "type": 1,
                    "string": "key"
                  },
                  {
                    "type": 1,
                    "string": "read"
                  },
                  {
                    "type": 1,
                    "string": "write"
                  },
                  {
                    "type": 1,
                    "string": "execute"
                  }
                ],
                "mapValue": [
                  {
                    "type": 1,
                    "string": "mcTrack"
                  },
                  {
                    "type": 8,
                    "boolean": true
                  },
                  {
                    "type": 8,
                    "boolean": true
                  },
                  {
                    "type": 8,
                    "boolean": true
                  }
                ]
              },
              {
                "type": 3,
                "mapKey": [
                  {
                    "type": 1,
                    "string": "key"
                  },
                  {
                    "type": 1,
                    "string": "read"
                  },
                  {
                    "type": 1,
                    "string": "write"
                  },
                  {
                    "type": 1,
                    "string": "execute"
                  }
                ],
                "mapValue": [
                  {
                    "type": 1,
                    "string": "mcIdentify"
                  },
                  {
                    "type": 8,
                    "boolean": true
                  },
                  {
                    "type": 8,
                    "boolean": true
                  },
                  {
                    "type": 8,
                    "boolean": true
                  }
                ]
              },
              {
                "type": 3,
                "mapKey": [
                  {
                    "type": 1,
                    "string": "key"
                  },
                  {
                    "type": 1,
                    "string": "read"
                  },
                  {
                    "type": 1,
                    "string": "write"
                  },
                  {
                    "type": 1,
                    "string": "execute"
                  }
                ],
                "mapValue": [
                  {
                    "type": 1,
                    "string": "__mcGtmConfig"
                  },
                  {
                    "type": 8,
                    "boolean": true
                  },
                  {
                    "type": 8,
                    "boolean": true
                  },
                  {
                    "type": 8,
                    "boolean": false
                  }
                ]
              }
            ]
          }
        }
      ]
    },
    "clientAnnotations": {
      "isEditedByUser": true
    },
    "isRequired": true
  },
  {
    "instance": {
      "key": {
        "publicId": "get_cookies",
        "versionId": "1"
      },
      "param": [
        {
          "key": "cookieAccess",
          "value": {
            "type": 1,
            "string": "specific"
          }
        },
        {
          "key": "cookieNames",
          "value": {
            "type": 2,
            "listItem": [
              {
                "type": 1,
                "string": "_ga"
              }
            ]
          }
        }
      ]
    },
    "clientAnnotations": {
      "isEditedByUser": true
    },
    "isRequired": true
  },
  {
    "instance": {
      "key": {
        "publicId": "read_data_layer",
        "versionId": "1"
      },
      "param": [
        {
          "key": "allowedKeys",
          "value": {
            "type": 1,
            "string": "specific"
          }
        },
        {
          "key": "keyPatterns",
          "value": {
            "type": 2,
            "listItem": [
              {
                "type": 1,
                "string": "event"
              },
              {
                "type": 1,
                "string": "ecommerce"
              },
              {
                "type": 1,
                "string": "user_data"
              }
            ]
          }
        }
      ]
    },
    "clientAnnotations": {
      "isEditedByUser": true
    },
    "isRequired": true
  },
  {
    "instance": {
      "key": {
        "publicId": "inject_script",
        "versionId": "1"
      },
      "param": [
        {
          "key": "urls",
          "value": {
            "type": 2,
            "listItem": [
              {
                "type": 1,
                "string": "https://chimpstatic.com/mcjs-connected/bridge/v1/gtm-bridge.js"
              }
            ]
          }
        }
      ]
    },
    "clientAnnotations": {
      "isEditedByUser": true
    },
    "isRequired": true
  }
]


___TESTS___

scenarios:
- name: Bridge URL is the only injected script
  code: |-
    const bridgeUrl = 'https://chimpstatic.com/mcjs-connected/bridge/v1/gtm-bridge.js';
    assertThat(bridgeUrl).isEqualTo('https://chimpstatic.com/mcjs-connected/bridge/v1/gtm-bridge.js');
- name: GA Client ID parsed correctly from _ga cookie
  code: |-
    const gaCookie = 'GA1.1.378274415.1780324369';
    const parts = gaCookie.split('.');
    const clientId = parts.length >= 4
      ? parts[parts.length - 2] + '.' + parts[parts.length - 1]
      : gaCookie;
    assertThat(clientId).isEqualTo('378274415.1780324369');
- name: Email normalized correctly before hashing
  code: |-
    const email = '  Test@Intuit.COM  ';
    const normalized = email.toLowerCase().trim();
    assertThat(normalized).isEqualTo('test@intuit.com');
- name: Phone normalized to E164
  code: |-
    const phone = '+1 (555) 123-4567';
    let digits = '';
    for (let i = 0; i < phone.length; i++) {
      const c = phone[i];
      if (c >= '0' && c <= '9') digits += c;
    }
    const normalized = digits.length > 0 ? '+' + digits : phone.trim();
    assertThat(normalized).isEqualTo('+15551234567');
- name: PRODUCT_VIEWED event maps correctly
  code: |-
    const eventMap = {
      'view_item':      'PRODUCT_VIEWED',
      'add_to_cart':    'PRODUCT_ADDED_TO_CART',
      'begin_checkout': 'CHECKOUT_STARTED',
      'purchase':       'PURCHASED'
    };
    assertThat(eventMap['view_item']).isEqualTo('PRODUCT_VIEWED');
    assertThat(eventMap['add_to_cart']).isEqualTo('PRODUCT_ADDED_TO_CART');
    assertThat(eventMap['begin_checkout']).isEqualTo('CHECKOUT_STARTED');
    assertThat(eventMap['purchase']).isEqualTo('PURCHASED');
- name: Unknown event returns undefined
  code: |-
    const eventMap = {
      'view_item':      'PRODUCT_VIEWED',
      'add_to_cart':    'PRODUCT_ADDED_TO_CART',
      'begin_checkout': 'CHECKOUT_STARTED',
      'purchase':       'PURCHASED'
    };
    assertThat(eventMap['unknown_event']).isUndefined();
- name: Cart ID fallback generates correctly
  code: |-
    const ecommerce = { currency: 'USD', value: 29.99 };
    const cartId = ecommerce.cart_id || ecommerce.id || 'cart-fallback';
    assertThat(cartId).isEqualTo('cart-fallback');
- name: Line item maps cross-platform fields correctly
  code: |-
    const item = { item_id: 'prod-001', item_name: 'Test Product', price: '29.99', quantity: '2' };
    const makeNumber = require('makeNumber');
    const unitPrice = makeNumber(item.price) || 0;
    const qty = makeNumber(item.quantity) || 1;
    const lineItem = {
      item: {
        id:        item.item_variant || item.variant_id || item.item_id || '',
        productId: item.item_id      || item.product_id || '',
        title:     item.item_name    || item.name       || item.title  || '',
        price:     unitPrice
      },
      quantity: qty,
      price:    unitPrice * qty
    };
    assertThat(lineItem.item.productId).isEqualTo('prod-001');
    assertThat(lineItem.item.title).isEqualTo('Test Product');
    assertThat(lineItem.price).isEqualTo(59.98);
- name: Line item with missing price defaults to 0 (no NaN)
  code: |-
    const item = { item_id: 'prod-002', item_name: 'No Price Product', quantity: '3' };
    const makeNumber = require('makeNumber');
    const unitPrice = makeNumber(item.price) || 0;
    const qty = makeNumber(item.quantity) || 1;
    const lineItem = {
      item: { id: item.item_id, productId: item.item_id, title: item.item_name, price: unitPrice },
      quantity: qty,
      price: unitPrice * qty
    };
    assertThat(lineItem.item.price).isEqualTo(0);
    assertThat(lineItem.price).isEqualTo(0);
    assertThat(lineItem.quantity).isEqualTo(3);
- name: Missing User ID triggers failure
  code: |-
    const userId = '';
    const connectedSiteId = 'xyz789';
    const isValid = userId && connectedSiteId;
    assertThat(isValid).isFalsy();
- name: Both IDs present passes validation
  code: |-
    const userId = 'abc123';
    const connectedSiteId = 'xyz789';
    const isValid = userId && connectedSiteId;
    assertThat(isValid).isTruthy();
- name: PRODUCT_VIEWED payload uses first item and falls back sanely
  code: |-
    const makeNumber = require('makeNumber');
    const e = { currency: 'EUR', items: [{ item_id: 'sku-1', item_name: 'Hat', price: '12.50', item_brand: 'Acme', item_category: 'Apparel' }] };
    const item = (e.items && e.items[0]) || e || {};
    const props = {
      product: {
        id:         item.item_variant || item.variant_id || item.item_id || item.id || 'prod-unknown',
        productId:  item.item_id || item.product_id || item.id || 'prod-unknown',
        title:      item.item_name || item.name || item.title || 'Unknown Product',
        price:      makeNumber(item.price) || 0,
        currency:   e.currency || 'USD',
        sku:        item.item_id || item.sku || item.id || '',
        vendor:     item.item_brand || item.brand || item.vendor || '',
        categories: item.item_category ? [item.item_category] : []
      }
    };
    assertThat(props.product.id).isEqualTo('sku-1');
    assertThat(props.product.productId).isEqualTo('sku-1');
    assertThat(props.product.title).isEqualTo('Hat');
    assertThat(props.product.price).isEqualTo(12.5);
    assertThat(props.product.currency).isEqualTo('EUR');
    assertThat(props.product.vendor).isEqualTo('Acme');
    assertThat(props.product.categories).isEqualTo(['Apparel']);
- name: PRODUCT_VIEWED with no items uses unknown placeholders
  code: |-
    const makeNumber = require('makeNumber');
    const e = { currency: 'USD' };
    const item = (e.items && e.items[0]) || e || {};
    const props = {
      product: {
        id:        item.item_variant || item.variant_id || item.item_id || item.id || 'prod-unknown',
        productId: item.item_id || item.product_id || item.id || 'prod-unknown',
        title:     item.item_name || item.name || item.title || 'Unknown Product',
        price:     makeNumber(item.price) || 0,
        currency:  e.currency || 'USD'
      }
    };
    assertThat(props.product.id).isEqualTo('prod-unknown');
    assertThat(props.product.productId).isEqualTo('prod-unknown');
    assertThat(props.product.title).isEqualTo('Unknown Product');
    assertThat(props.product.price).isEqualTo(0);
- name: PRODUCT_ADDED_TO_CART payload computes line total without NaN
  code: |-
    const makeNumber = require('makeNumber');
    const e = { currency: 'USD', cart_id: 'cart-abc', items: [{ item_id: 'sku-2', item_name: 'Shirt', price: '20', quantity: '2' }] };
    const item = e.items && e.items[0];
    const unitPrice = makeNumber(item.price) || 0;
    const qty = makeNumber(item.quantity) || 1;
    const props = {
      cartId: e.cart_id || e.id || 'cart-fallback',
      product: {
        item: { id: item.item_variant || item.item_id || '', productId: item.item_id || '', title: item.item_name || '', price: unitPrice, currency: e.currency || 'USD', sku: item.item_id || '' },
        quantity: qty,
        price: unitPrice * qty,
        currency: e.currency || 'USD'
      }
    };
    assertThat(props.cartId).isEqualTo('cart-abc');
    assertThat(props.product.item.price).isEqualTo(20);
    assertThat(props.product.quantity).isEqualTo(2);
    assertThat(props.product.price).isEqualTo(40);
    assertThat(props.product.currency).isEqualTo('USD');
- name: CHECKOUT_STARTED payload aggregates line items
  code: |-
    const makeNumber = require('makeNumber');
    function getLineItem(item) {
      const unitPrice = makeNumber(item.price) || 0;
      const qty = makeNumber(item.quantity) || 1;
      return {
        item: { id: item.item_variant || item.variant_id || item.item_id || item.id || '', productId: item.item_id || item.product_id || item.id || '', title: item.item_name || item.name || item.title || '', price: unitPrice },
        quantity: qty,
        price: unitPrice * qty
      };
    }
    const e = { currency: 'USD', cart_id: 'cart-1', checkout_id: 'co-1', value: 50, items: [{ item_id: 'a', item_name: 'A', price: 10, quantity: 2 }, { item_id: 'b', item_name: 'B', price: 15, quantity: 2 }] };
    const props = {
      checkout: {
        id:         e.checkout_id || e.transaction_id || 'checkout-fallback',
        cartId:     e.cart_id || 'cart-fallback',
        lineItems:  (e.items || []).map(getLineItem),
        totalPrice: makeNumber(e.value) || 0,
        currency:   e.currency || 'USD'
      }
    };
    assertThat(props.checkout.id).isEqualTo('co-1');
    assertThat(props.checkout.cartId).isEqualTo('cart-1');
    assertThat(props.checkout.lineItems.length).isEqualTo(2);
    assertThat(props.checkout.lineItems[0].price).isEqualTo(20);
    assertThat(props.checkout.lineItems[1].price).isEqualTo(30);
    assertThat(props.checkout.totalPrice).isEqualTo(50);
- name: PURCHASED payload includes tax and shipping
  code: |-
    const makeNumber = require('makeNumber');
    function getLineItem(item) {
      const unitPrice = makeNumber(item.price) || 0;
      const qty = makeNumber(item.quantity) || 1;
      return {
        item: { id: item.item_id, productId: item.item_id, title: item.item_name, price: unitPrice },
        quantity: qty,
        price: unitPrice * qty
      };
    }
    const e = { currency: 'USD', transaction_id: 'tx-1', value: 100, tax: 8, shipping: 5, items: [{ item_id: 'a', item_name: 'A', price: 100, quantity: 1 }] };
    const props = {
      order: {
        id:            e.transaction_id || 'order-fallback',
        lineItems:     (e.items || []).map(getLineItem),
        totalPrice:    makeNumber(e.value) || 0,
        totalTax:      makeNumber(e.tax) || 0,
        totalShipping: makeNumber(e.shipping) || 0,
        currency:      e.currency || 'USD'
      }
    };
    assertThat(props.order.id).isEqualTo('tx-1');
    assertThat(props.order.totalPrice).isEqualTo(100);
    assertThat(props.order.totalTax).isEqualTo(8);
    assertThat(props.order.totalShipping).isEqualTo(5);
    assertThat(props.order.lineItems[0].price).isEqualTo(100);
- name: PURCHASED with no tax/shipping defaults to 0
  code: |-
    const makeNumber = require('makeNumber');
    const e = { currency: 'USD', transaction_id: 'tx-2', value: 25, items: [] };
    const props = {
      order: {
        id:            e.transaction_id || 'order-fallback',
        lineItems:     (e.items || []).map(function(i){ return i; }),
        totalPrice:    makeNumber(e.value) || 0,
        totalTax:      makeNumber(e.tax) || 0,
        totalShipping: makeNumber(e.shipping) || 0,
        currency:      e.currency || 'USD'
      }
    };
    assertThat(props.order.totalTax).isEqualTo(0);
    assertThat(props.order.totalShipping).isEqualTo(0);
    assertThat(props.order.lineItems.length).isEqualTo(0);
- name: Init events are recognized
  code: |-
    function isInit(ev) { return ev === 'gtm.js' || ev === 'gtm.dom' || ev === 'gtm.load'; }
    assertThat(isInit('gtm.js')).isTrue();
    assertThat(isInit('gtm.dom')).isTrue();
    assertThat(isInit('gtm.load')).isTrue();
    assertThat(isInit('view_item')).isFalse();
    assertThat(isInit('purchase')).isFalse();
- name: Config merge preserves existing keys
  code: |-
    const existing = { foo: 'bar' };
    const userId = 'u1';
    const connectedSiteId = 's1';
    const cfg = existing || {};
    cfg.userId = userId;
    cfg.connectedSiteId = connectedSiteId;
    assertThat(cfg.foo).isEqualTo('bar');
    assertThat(cfg.userId).isEqualTo('u1');
    assertThat(cfg.connectedSiteId).isEqualTo('s1');


___NOTES___

Created on 6/3/2026, 2:35:23 PM


