/**
 * Writes enterprise_provisioning_qr.png + normal_apk_install_qr.png.
 * Avoids Windows cmd quoting bugs (JSON) and flaky qrcode CLI on some setups.
 */
const path = require("path");
const fs = require("fs");
const util = require("util");
const QRCode = require("qrcode");

const toFile = util.promisify(QRCode.toFile);

const root = path.join(__dirname, "..");
const pngOpts = { type: "png", width: 512, margin: 2 };

async function main() {
  const payloadPath = path.join(root, "qr_payload_enterprise_provisioning.json");
  const payload = require(payloadPath);
  const text = JSON.stringify(payload);
  const enterpriseOut = path.join(root, "enterprise_provisioning_qr.png");
  const minPath = path.join(root, "enterprise_provisioning_payload.min.json");

  await toFile(enterpriseOut, text, pngOpts);
  fs.writeFileSync(minPath, text, "utf8");
  console.log("Wrote", enterpriseOut);

  const urlPath = path.join(root, "qr_payload_normal_apk_url.txt");
  const url = fs.readFileSync(urlPath, "utf8").trim().split(/\r?\n/)[0];
  if (!url) {
    throw new Error("qr_payload_normal_apk_url.txt is empty");
  }
  const normalOut = path.join(root, "normal_apk_install_qr.png");
  await toFile(normalOut, url, pngOpts);
  console.log("Wrote", normalOut);
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
