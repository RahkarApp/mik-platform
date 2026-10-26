# Shared products

Authenticated MiK and MiKYar enter the same PIM pages in `product/pim` through
their existing product entry. MiK uses the business selected at login or
onboarding. MiKYar continues from login to products, selects its active business
automatically when there is only one, and otherwise uses the shared picker.
The existing legacy screens remain available for legacy sessions and other
features that have not migrated yet.

Product creation keeps the original `MyMultiFAB` menu, with “افزودن تکی” and
“افزودن گروهی”. Single entry opens `ProductGroupDetailsScreen`; group entry
opens the existing `ProductGroupAddScreen` chatbot and then the same details
screen with its product steps, previous/next/skip actions and final summary.
`PimGroupDetailsController` adapts this flow to PIM; these entry points must not
be replaced with a generic editor when changing the API integration.

The product UI follows the existing shared components: `Main`, `Header`,
`MyTabBar`, `MySearchBar`, `MyMultiFAB`, `MyFAB`, `MyBottomSheet`, `MyTab`, `EmptyList`,
`EndLine`, `Input`, `Dropdown`, `PriceInput`, `DateInput`, `BTN` and Iconsax.
Rows use the actual `ProductItem`, `PropertyItem` and `CategoryItem` widgets,
including their original sheets and product image placeholder. The product item
opens its original bottom sheet for simple products and `ProductItemDetails`
for products with variant axes. Both paths use `ProductDet`; they must not be
replaced with a separate PIM detail or record tile.

Product features keep the flow from `Desktop/mik-app`: the original
`AddFeatureSheet` opens from “افزودن/ویرایش ویژگی”, selections use chips and
“همه”, and confirmation updates the original combinations table.
`PropertySheet` creates/edits feature definitions inline using the PIM API.
New enumerated features use SELECT with stable option UUIDs and
`usableForVariant: true`; removed options are deactivated. Definition edits
require their real owner/`.all` permission. Product axes are staged until
confirmation and retained in drafts. Saving changed axes on an existing product
also generates its combinations when permitted; an uncertain generation resumes
its original command after reopening, without repeating the product PATCH.
`mik_components` files must not be edited; adapt the existing page callers.

Editing reuses `ProductGroupDetailsScreen`, `AddCategoryForm`,
`ProductPropertyAddScreen` and `PropertyValueForm`. Pricing reuses
`ProductPriceScreen.priceItem`, its price sheet and variant expansion/number pad;
variant preview/generation lives in `ProductProScreen`. The PIM FX and typed
controllers adapt the server without constructing legacy Hive records. Option
UUIDs, color hex values and inactive options survive edits. Server archive uses
revisioned PATCH, and uncertain requests retain their original idempotency key.
Product lists render the original shared `ProductItem` through its typed
`ProductItem.remote` constructor, using the same layout and `ProductImage`.
Category and price fields require their own server read grants; missing inventory
data is not presented as zero. Product icons use `IconsaxPlusLinear`.
Each widget has its own file. Price inputs explicitly use tomans, matching the
API, independently of the app's display currency.

For a focused change, run its relevant tests; do not run the whole suite by default.

`BusinessContext` binds the selected business to the app, API origin, identity
and server session. Changing account/business invalidates previous contexts.
`PimFX` loads BUSINESS authorization from the server and uses `AuthFX.request`
for all protected requests. Neither owner UI flags nor legacy bit strings grant
PIM permissions. Each tab requires its own read grant; product reads never fetch
prices or stock implicitly. Attribute and price changes to another creator's
records require both the base grant and its `.all` grant. Shop editing,
attribute assignment, variant operations and changing default prices each use
their own permissions. A 403 clears cached PIM grants; refresh reloads them.
Returning to the app also refreshes the business authorization and list.

The shared implementation supports paginated lists, local name filtering,
status filtering, draft product creation, revisioned edits, archive/restore,
standard category import, custom child categories, brands, typed attributes
with stable option UUIDs, variant preview/generation, barcodes, named prices,
validity dates, default prices and per-variant overrides. Units and category
IDs come from server responses. Simple products use the server-created BASE
variant. Zero is a valid price; PRICE_UNAVAILABLE is displayed explicitly.

Conversation and form drafts are stored separately for each app, API origin,
identity and business. Group submission persists the command queue and progress
before continuing. Reopening resumes the saved failed command with its original
key/body, preserves already created products and only clears the submitted
drafts after all their operations succeed. Product creation, variant generation,
named/default prices and activation each require their actual server grants.

Mutations carry a UUID Idempotency-Key and PATCH includes expectedRevision.
Before transmission, the immutable command is saved in secure storage scoped
by app, origin, identity and business. Uncertain failures retain it, freeze the
form and offer retry of that same command, including after navigating back or
restarting. Revision conflicts require receiving a fresh record. No legacy
SaveHelper, fabricated Hive product or v2 mutation is used by the PIM pages.

Inventory movements, stocktaking, valuation, accounting/invoice integration and
realtime transport remain their separate migrations. The gateway currently
has no media upload endpoint; these pages do not invent a file upload URL or
write image files through the old API. Existing server fields that are not
edited remain intact because updates send only changed fields.

Validation uses mocked HTTP, form and widget tests, including the MiKYar host
entry and permission restrictions. It does not mutate a deployed backend.
