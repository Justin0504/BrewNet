# Coffee Vouchers Setup Guide

## Image Assets Location

The 5 coffee voucher images should be placed in the following locations in Xcode:

### Path Structure:
```
BrewNet/BrewNet/Assets.xcassets/
├── CoffeeVoucher1.imageset/
│   ├── Contents.json
│   └── [Your image file here - e.g., CoffeeVoucher1.png]
├── CoffeeVoucher2.imageset/
│   ├── Contents.json
│   └── [Your image file here - e.g., CoffeeVoucher2.png]
├── CoffeeVoucher3.imageset/
│   ├── Contents.json
│   └── [Your image file here - e.g., CoffeeVoucher3.png]
├── CoffeeVoucher4.imageset/
│   ├── Contents.json
│   └── [Your image file here - e.g., CoffeeVoucher4.png]
└── CoffeeVoucher5.imageset/
    ├── Contents.json
    └── [Your image file here - e.g., CoffeeVoucher5.png]
```

## How to Add Images in Xcode:

1. Open Xcode
2. Navigate to `BrewNet/BrewNet/Assets.xcassets` in the Project Navigator
3. You should see the 5 imageset folders already created:
   - `CoffeeVoucher1.imageset`
   - `CoffeeVoucher2.imageset`
   - `CoffeeVoucher3.imageset`
   - `CoffeeVoucher4.imageset`
   - `CoffeeVoucher5.imageset`

4. For each imageset:
   - Click on the imageset folder (e.g., `CoffeeVoucher1.imageset`)
   - Drag and drop your image file into the imageset in Xcode
   - Xcode will automatically update the `Contents.json` file

## Image Order and Details:

1. **CoffeeVoucher1** (45 credits)
   - Starbucks Crème Frappuccino
   - Image: Starbucks logo with Crème Frappuccino cup

2. **CoffeeVoucher2** (55 credits)
   - Starbucks Pumpkin Spice Latte / Iced Espresso
   - Image: Starbucks logo with Pumpkin Spice Latte cup

3. **CoffeeVoucher3** (35 credits)
   - Dunkin' Cold Brew with Sweet Cold Foam
   - Image: Dunkin' logo with Cold Brew cup

4. **CoffeeVoucher4** (25 credits)
   - Tim Hortons Double Double
   - Image: Tim Hortons logo with red coffee cup

5. **CoffeeVoucher5** (30 credits)
   - Dunkin' Caramel Craze Signature Latte
   - Image: Dunkin' logo with Caramel Craze Latte cup

## Notes:

- Image names in code: `CoffeeVoucher1`, `CoffeeVoucher2`, `CoffeeVoucher3`, `CoffeeVoucher4`, `CoffeeVoucher5`
- The images will be automatically loaded when the rewards are displayed
- If an image is not found, the system will fall back to the default coffee icon

