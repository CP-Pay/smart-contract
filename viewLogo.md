# 🎨 How to View Your BLL Token Logo

Your logo is stored onchain in your Diamond contract! Here are multiple ways to view it:

## Method 1: Quick View - Open HTML File ⚡ (EASIEST)

1. **Open the file `view-logo.html` in your browser**
   - Just double-click the file
   - Or drag it into your browser

2. **Paste your SVG code** (from the contract call result) into the text box

3. **Click "Display Logo"** - Boom! Your logo appears! 🎉

---

## Method 2: Fetch from Contract 🔗 (AUTOMATED)

### Step 1: Get your Diamond address from the deployment
Check your last deployment output for the Diamond Proxy address.

### Step 2: Run the fetch script
```bash
# Replace with your actual Diamond address
DIAMOND_ADDRESS=0xYourDiamondAddress npx hardhat run scripts/fetch-logo.ts --network lisk
```

This will create:
- ✅ `BLL_logo.svg` - The raw SVG file
- ✅ `BLL_logo_preview.html` - Beautiful HTML preview
- ✅ `BLL_metadata.json` - Token metadata

### Step 3: Open the preview
```bash
# Open in browser (Mac)
open BLL_logo_preview.html

# Open in browser (Linux)
xdg-open BLL_logo_preview.html

# Or just double-click the file
```

---

## Method 3: Call Contract Directly on Blockscout 🔍

1. Go to your Diamond contract on Blockscout:
   `https://sepolia-blockscout.lisk.com/address/YOUR_DIAMOND_ADDRESS`

2. Click **"Read Contract"** or **"Read Proxy"** tab

3. Find and expand **`getLogo()`** function

4. Click **"Query"**

5. Copy the SVG output

6. Open `view-logo.html` and paste it there!

---

## Method 4: Using ethers.js in Code 💻

```javascript
const { ethers } = require("ethers");

const provider = new ethers.JsonRpcProvider("https://rpc.sepolia-api.lisk.com");
const diamondAddress = "YOUR_DIAMOND_ADDRESS";

const abi = ["function getLogo() external view returns (string memory)"];
const contract = new ethers.Contract(diamondAddress, abi, provider);

const logo = await contract.getLogo();
console.log(logo); // Your SVG code!

// Save to file
const fs = require("fs");
fs.writeFileSync("logo.svg", logo);
```

---

## Method 5: Download from Website 📥

Using the `view-logo.html` file:

1. Open `view-logo.html`
2. Paste your SVG or connect to contract
3. Click **"Download Logo as SVG"** or **"Download Logo as PNG"**
4. Use the logo anywhere!

---

## What You Can Do with the Logo

✅ Use it on your website  
✅ Add it to your documentation  
✅ Create marketing materials  
✅ Share on social media  
✅ Print it on merchandise  
✅ Use as app icon  

---

## Quick Test (No Deployment Needed)

Want to see what your logo looks like right now? Here's the SVG code:

\`\`\`xml
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 400 400">
  <defs>
    <linearGradient id="grad1" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" style="stop-color:#667eea;stop-opacity:1" />
      <stop offset="100%" style="stop-color:#764ba2;stop-opacity:1" />
    </linearGradient>
    <filter id="shadow">
      <feDropShadow dx="0" dy="4" stdDeviation="4" flood-opacity="0.3"/>
    </filter>
  </defs>
  <rect width="400" height="400" fill="url(#grad1)"/>
  <circle cx="200" cy="200" r="120" fill="white" fill-opacity="0.2" filter="url(#shadow)"/>
  <text x="200" y="180" font-family="Arial, sans-serif" font-size="80" font-weight="bold" fill="white" text-anchor="middle" filter="url(#shadow)">BLL</text>
  <text x="200" y="240" font-family="Arial, sans-serif" font-size="24" fill="white" fill-opacity="0.9" text-anchor="middle">BLL Token</text>
  <circle cx="200" cy="200" r="140" fill="none" stroke="white" stroke-width="2" stroke-opacity="0.3"/>
  <circle cx="200" cy="200" r="155" fill="none" stroke="white" stroke-width="1" stroke-opacity="0.2"/>
</svg>
\`\`\`

Copy this, paste into `view-logo.html`, and see your logo! 🎨

---

## Troubleshooting

**Logo shows empty text?**
- The contract might not be initialized yet
- Check if `name` and `symbol` are set in your ERC20 storage

**Can't fetch from contract?**
- Make sure TokenURIFacet is deployed and added to the diamond
- Check you're using the correct network
- Verify the Diamond address is correct

**Need help?**
- Check the deployment output for your Diamond address
- Make sure the contract is verified on Blockscout
- Try fetching via Blockscout's "Read Contract" tab first

---

## Pro Tips 💡

1. **Save the logo files** - They're generated from your contract!
2. **The logo is immutable** - Once deployed, it's stored forever onchain
3. **You can update metadata** - Use `setTokenMetadata()` function (if you haven't removed it)
4. **Share the base64 tokenURI** - It contains everything (logo + metadata)!

Happy viewing! 🚀
