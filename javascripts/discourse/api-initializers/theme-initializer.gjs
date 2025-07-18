import { apiInitializer } from "discourse/lib/api";

const preloadedDataString = document.getElementById("data-preloaded").getAttribute("data-preloaded");
const preloadedData = JSON.parse(preloadedDataString);
console.log({ preloadedData });

function showLoading() {
  if (!swal.isVisible()) {
    Swal.fire({
      title: "Đang tải...",
      text: "Đang chờ quá trình hoàn tất.",
      allowOutsideClick: false,
      didOpen: () => {
        Swal.showLoading();
      },
    });
  }
}

async function showMessage(title, message) {
  return await Swal.fire({ width: 800, icon: "error", title, text: message });
}

function extractIMEI(str) {
  const match = str.match(/IMEI\((\d+)\)/);
  if (match) {
    return match[1]; // match[1] chứa chuỗi số IMEI
  }
  return null; // không tìm thấy
}

// Xử lý sự kiện khi người dùng nhấn nút kết nối
async function btnClickHandle() {
  let port; // Biến để lưu đối tượng cổng COM
  let reader; // Biến để lưu reader
  let writer; // Biến để lưu writer

  try {
    // Yêu cầu chọn cổng COM
    port = await navigator.serial.requestPort();

    await port.open({ baudRate: 9600 });

    showLoading();

    // Gửi dữ liệu đến thiết bị
    writer = port.writable.getWriter();
    const encoder = new TextEncoder();
    await writer.write(encoder.encode("AT+DEVCONINFO\r\n"));
    writer.releaseLock();

    // Đọc dữ liệu trả về từ thiết bị
    reader = port.readable.getReader();
    const decoder = new TextDecoder(); // Sử dụng TextDecoder trực tiếp

    let response = ""; // Bộ đệm để lưu trữ dữ liệu nhận được

    // Hiển thị dữ liệu nhận từ thiết bị
    while (true) {
      const { value, done } = await reader.read();

      if (done) break;

      // Chuyển đổi dữ liệu từ Uint8Array thành chuỗi
      response += decoder.decode(value, { stream: true });

      // Nếu bạn muốn xử lý dữ liệu khi nhận được đủ dữ liệu
      if (response.includes("#OK#")) {
        // Trích xuất số imei 15 ký tự trong phản hồi usb
        const imei = extractIMEI(response);
        return await checkKnoxSendPayload({ imei });
      }
    }
  } catch (err) {
    console.log(err.message);
  }

  // Đảm bảo rằng cổng COM được đóng sau khi hoàn tất giao tiếp
  if (reader) reader.releaseLock(); // Giải phóng lock của reader
  if (writer) writer.releaseLock(); // Giải phóng lock của writer
  if (port && port.readable) {
    await port.close();
  }
}

async function resizeImage(blob, maxWidth, maxHeight) {
  return new Promise((resolve, reject) => {
    const img = new Image();
    img.onload = () => {
      const canvas = document.createElement("canvas");
      let width = img.width;
      let height = img.height;

      if (width > height) {
        if (width > maxWidth) {
          height *= maxWidth / width;
          width = maxWidth;
        }
      } else {
        if (height > maxHeight) {
          width *= maxHeight / height;
          height = maxHeight;
        }
      }

      canvas.width = width;
      canvas.height = height;
      const ctx = canvas.getContext("2d");
      ctx.drawImage(img, 0, 0, width, height);

      canvas.toBlob(resolve, "image/jpeg", 0.7); // Adjust quality as needed
    };
    img.onerror = reject;
    img.src = URL.createObjectURL(blob);
  });
}

async function openImageToCheckIMEI() {
  await Swal.fire({
    title: "Tải ảnh để kiểm tra IMEI",
    html: `
      <input id="swal-image" type="file" class="swal2-file" accept="image/*">
      <p style="margin-top:10px; font-size:0.9em;">Bạn cũng có thể dán hình ảnh (Ctrl + V)</p>
    `,
    confirmButtonText: "Dán từ bộ nhớ tạm",
    showCloseButton: true,
    didOpen: () => {
      const blobToBase64 = (blob) => {
        return new Promise((resolve, reject) => {
          const reader = new FileReader();
          reader.onloadend = () => resolve(reader.result);
          reader.onerror = reject;
          reader.readAsDataURL(blob);
        });
      };

      const handleImage = async (blobOrFile) => {
        if (!blobOrFile) return;

        try {
          Swal.showLoading();
          const resizedBlob = await resizeImage(blobOrFile, 800, 800);
          const base64 = await blobToBase64(resizedBlob);
          const imageBase64 = base64.split(",")[1];
          const response = await fetch("https://gp3al2u6vadd4w6guhrw5bgf3u0hceyh.lambda-url.ap-southeast-1.on.aws/text-track", {
            method: "POST",
            headers: { "Content-Type": "application/json" },
            body: JSON.stringify({ image: imageBase64 }),
          });

          if (!response.ok) throw new Error("Gửi ảnh thất bại");

          const { TextDetections } = await response.json();
          const lines = TextDetections.filter(({ Type }) => Type === "LINE").map(({ DetectedText }) => DetectedText);
          const match = lines.join(" ").match(/\b\d{15}\b/);

          if (!match) throw new Error("Không tìm thấy IMEI hợp lệ");

          const imei = match[0];
          console.log("IMEI tìm được:", imei);

          await checkKnoxSendPayload({ imei });
        } catch (error) {
          Swal.showValidationMessage("Lỗi: " + error.message);
        }

        swal.hideLoading();
      };

      const handleFileInputChange = (e) => {
        const file = e.target.files[0];
        handleImage(file);
      };

      const handleClipboardPaste = async () => {
        try {
          if (!navigator.clipboard || !navigator.clipboard.read) {
            return await showMessage("", "Trình duyệt không hỗ trợ truy cập clipboard hình ảnh.");
          }

          const clipboardItems = await navigator.clipboard.read();
          for (const clipboardItem of clipboardItems) {
            for (const type of clipboardItem.types) {
              if (type.startsWith("image/")) {
                const blob = await clipboardItem.getType(type);
                return await handleImage(blob);
              }
            }
          }
        } catch (err) {
          console.log(err);
          return await showMessage("", "Không thể truy cập clipboard. Hãy đảm bảo bạn đã sao chép một ảnh và trình duyệt cho phép.");
        }
      };

      const pasteHandle = async (e) => {
        const items = e.clipboardData.items;
        for (let item of items) {
          if (item.type.startsWith("image/")) {
            return await handleImage(item.getAsFile());
          }
        }
      };

      document.getElementById("swal-image").addEventListener("change", handleFileInputChange);
      document.querySelector(".swal2-confirm").addEventListener("click", handleClipboardPaste);
      document.removeEventListener("paste", pasteHandle);
      document.addEventListener("paste", pasteHandle);
    },
  });
}

async function showStep1() {
  //
  const { value: inputData } = await Swal.fire({
    title: "Nhập số IMEI hoặc Seri",
    input: "text",
    inputPlaceholder: "Nhập IMEI hoặc Seri tại đây...",
    inputValue: "",
    showCancelButton: true,
    confirmButtonText: "Tra cứu",
    cancelButtonText: "Quay lại",
    inputValidator: (value) => {
      if (![11, 15].includes(value.length)) {
        return "IMEI 15 ký tự / SN 11 ký tự";
      }
    },
  });

  if (!inputData) return;

  const imei = inputData.length === 15 ? inputData.toUpperCase() : null;
  const serial = inputData.length === 11 ? inputData.toUpperCase() : null;

  await checkKnoxSendPayload({ imei, serial });
}

async function checkKnoxSendPayload(payload) {
  try {
    //
    showLoading();

    if (!preloadedData.currentUser) {
      return document.querySelector(".login-button").click();
    }

    const user = JSON.parse(preloadedData.currentUser);

    const url = "https://serverforcheckknoxdotcom.checkknoxdotcom.workers.dev/check";
    const fetchHeaders = { "Accept": "application/json, text/javascript, */*; q=0.01", "Content-Type": "application/json" };

    const response = await fetch(url, { method: "POST", headers: fetchHeaders, body: JSON.stringify({ ...payload, user }) });

    const { post_url, error, message } = await response.json();

    if (post_url) window.location.href = post_url;

    if (error) {
      await showMessage(error, message);
    }

    //
  } catch (error) {
    return await showMessage("Error during API call", error.message);
  }
}

export default apiInitializer((api) => {
  //
  const observer = new MutationObserver((mutations) => {
    mutations.forEach((mutation) => {
      mutation.addedNodes.forEach(async (node) => {
        if (node.nodeType === Node.ELEMENT_NODE) {
          if (node.classList) {
            if (node.classList.contains("knox-input")) {
              node.onclick = showStep1;
              node.onkeyup = () => {
                node.value = "";
              };
            } else if (node.classList.contains("knox-btn-com-port")) {
              node.onclick = btnClickHandle;
            } else if (node.classList.contains("knox-btn-image-text-track")) {
              node.onclick = openImageToCheckIMEI;
            }
          }
        }
      });
    });
  });

  observer.observe(document.body, { childList: true, subtree: true });
  //
});
