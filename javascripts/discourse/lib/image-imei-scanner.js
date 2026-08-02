import { showMessage } from "./swal-loading";
import { resizeImage, blobToBase64 } from "./image-helpers";
import { checkKnoxSendPayload } from "./knox-api";

const TEXT_TRACK_URL =
  "https://gp3al2u6vadd4w6guhrw5bgf3u0hceyh.lambda-url.ap-southeast-1.on.aws/text-track";

export async function openImageToCheckIMEI() {
  await Swal.fire({
    title: "Tải ảnh để kiểm tra IMEI",
    html: `
      <input id="swal-image" type="file" class="swal2-file" accept="image/*">
      <p style="margin-top:10px; font-size:0.9em;">Bạn cũng có thể dán hình ảnh (Ctrl + V)</p>
    `,
    confirmButtonText: "Dán từ bộ nhớ tạm",
    showCloseButton: true,
    preConfirm: async () => {
      try {
        if (!navigator.clipboard || !navigator.clipboard.read) {
          throw new Error("Trình duyệt không hỗ trợ truy cập bộ nhớ tạm.");
        }
        Swal.showLoading();
        const clipboardItems = await navigator.clipboard.read();
        const hasImage = clipboardItems.some((c) =>
          c.types.some((t) => t.startsWith("image/"))
        );
        if (!hasImage) throw new Error("Không có hình ảnh nào trong bộ nhớ tạm.");
        Swal.showValidationMessage("Đang lấy ảnh từ bộ nhớ tạm");
      } catch (err) {
        Swal.showValidationMessage(err.message);
      }
    },
    didOpen: () => {
      const handleImage = async (blobOrFile) => {
        if (!blobOrFile) return;

        try {
          Swal.showLoading();

          const resizedBlob = await resizeImage(blobOrFile, 800, 800);
          const base64 = await blobToBase64(resizedBlob);
          const imageBase64 = base64.split(",")[1];
          const response = await fetch(TEXT_TRACK_URL, {
            method: "POST",
            headers: { "Content-Type": "application/json" },
            body: JSON.stringify({ image: imageBase64 }),
          });

          if (!response.ok) throw new Error("Gửi ảnh thất bại");

          const { TextDetections } = await response.json();
          const lines = TextDetections
            .filter(({ Type }) => Type === "LINE")
            .map(({ DetectedText }) => DetectedText);
          const match = lines.join(" ").match(/\b\d{15}\b/);

          if (!match) throw new Error("Không tìm thấy IMEI hợp lệ");

          const imei = match[0];
          console.log("IMEI tìm được:", imei);

          await checkKnoxSendPayload({ imei });
        } catch (error) {
          Swal.showValidationMessage("Lỗi: " + error.message);
        }
      };

      const handleFileInputChange = (e) => {
        const file = e.target.files[0];
        handleImage(file);
      };

      const handleClipboardPaste = async () => {
        try {
          if (!navigator.clipboard || !navigator.clipboard.read) {
            throw new Error("Trình duyệt không hỗ trợ truy cập clipboard hình ảnh.");
          }
          const clipboardItems = await navigator.clipboard.read();
          for (const clipboardItem of clipboardItems) {
            for (const type of clipboardItem.types) {
              if (type.startsWith("image/")) {
                const blob = await clipboardItem.getType(type);
                await handleImage(blob);
                break;
              }
            }
          }
        } catch (err) {
          await showMessage("read clipboard error", err.message);
        }
      };

      const pasteHandle = async (e) => {
        const items = e.clipboardData.items;
        for (let item of items) {
          if (item.type.startsWith("image/")) {
            await handleImage(item.getAsFile());
            break;
          }
        }
      };

      document
        .getElementById("swal-image")
        .addEventListener("change", handleFileInputChange);
      document
        .querySelector(".swal2-confirm")
        .addEventListener("click", handleClipboardPaste);
      document.removeEventListener("paste", pasteHandle);
      document.addEventListener("paste", pasteHandle);
    },
  });
}