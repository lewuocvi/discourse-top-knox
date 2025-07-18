import { apiInitializer } from "discourse/lib/api";

let data = "";

function showLoading(isLoading) {
  if (isLoading) {
    Swal.fire({
      title: "Đang tải...",
      text: "Đang chờ quá trình hoàn tất.",
      allowOutsideClick: false,
      didOpen: () => {
        Swal.showLoading();
      },
    });
  } else {
    Swal.close();
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

    showLoading(true);

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
        data = extractIMEI(response);
        await showStep1();
        break; // Dừng vòng lặp khi đã nhận đủ dữ liệu
      }
    }
  } catch (err) {
    await showMessage("", err.message);
  }

  showLoading(false);

  // Đảm bảo rằng cổng COM được đóng sau khi hoàn tất giao tiếp
  if (reader) reader.releaseLock(); // Giải phóng lock của reader
  if (writer) writer.releaseLock(); // Giải phóng lock của writer
  if (port && port.readable) {
    await port.close();
  }
}

async function openImageToCheckIMEI() {
  await Swal.fire({
    title: "Tải ảnh để kiểm tra IMEI",
    html: `
      <input id="swal-image" type="file" class="swal2-file" accept="image/*">
      <p style="margin-top:10px; font-size:0.9em;">Bạn cũng có thể dán hình ảnh (Ctrl + V)</p>
    `,
    showConfirmButton: false,
    showCancelButton: true,
    cancelButtonText: "Đóng",
    didOpen: () => {
      const fileInput = document.getElementById("swal-image");

      // Chuyển blob/file thành base64
      const blobToBase64 = (blob) => {
        return new Promise((resolve, reject) => {
          const reader = new FileReader();
          reader.onloadend = () => resolve(reader.result);
          reader.onerror = reject;
          reader.readAsDataURL(blob);
        });
      };

      // Xử lý ảnh từ base64
      const handleImage = async (blobOrFile) => {
        if (!blobOrFile) return;

        try {
          Swal.showLoading();

          const base64 = await blobToBase64(blobOrFile);
          const imageBase64 = base64.split(",")[1]; // nếu API không cần prefix

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
          data = match[0];

          console.log("IMEI tìm được:", data);

          await showStep1(data);
          Swal.close();
        } catch (error) {
          Swal.hideLoading();
          Swal.showValidationMessage("Lỗi: " + error.message);
        }
      };

      // Khi chọn file từ input
      fileInput.addEventListener("change", (e) => {
        const file = e.target.files[0];
        handleImage(file);
      });

      // Khi dán ảnh từ clipboard
      document.addEventListener(
        "paste",
        (e) => {
          const items = e.clipboardData.items;
          for (let item of items) {
            if (item.type.startsWith("image/")) {
              const blob = item.getAsFile();
              handleImage(blob);
              break;
            }
          }
        },
        { once: true }
      );
    },
  });
}

async function showStep1() {
  //
  const preloadedDataString = document.getElementById("data-preloaded").getAttribute("data-preloaded");
  const preloadedData = JSON.parse(preloadedDataString);
  console.log({ preloadedData });
  if (!preloadedData.currentUser) {
    return document.querySelector(".login-button").click();
  }
  const user = JSON.parse(preloadedData.currentUser);
  //
  const { value: inputData } = await Swal.fire({
    title: "Nhập số IMEI hoặc Seri",
    input: "text",
    inputPlaceholder: "Nhập IMEI hoặc Seri tại đây...",
    inputValue: data, // ← Giá trị mặc định
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

  try {
    //
    showLoading(true);
    const response = await fetch("https://serverforcheckknoxdotcom.checkknoxdotcom.workers.dev/check", {
      method: "POST",
      headers: {
        "Accept": "application/json, text/javascript, */*; q=0.01",
        "Content-Type": "application/json",
      },
      body: JSON.stringify({ imei, serial, user }),
    });
    const { post_url, error, message } = await response.json();
    showLoading(false);

    if (post_url) window.location.href = post_url;
    if (error) await showMessage(error, message);

    //
  } catch (error) {
    return await showMessage("Error during API call", error.message);
  } finally {
    showLoading(false);
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
