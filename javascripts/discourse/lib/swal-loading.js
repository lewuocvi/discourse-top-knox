export class SwalLoading {
  static show() {
    Swal.fire({
      title: "Đang tải...",
      text: "Đang chờ quá trình hoàn tất.",
      allowOutsideClick: false,
      didOpen: () => Swal.showLoading(),
    });
  }

  static close() {
    Swal.close();
  }
}

export async function showMessage(title, message) {
  return await Swal.fire({ width: 800, icon: "error", title, text: message });
}
