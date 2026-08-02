import { SwalLoading } from "./swal-loading";
import { checkKnoxSendPayload } from "./knox-api";

function extractIMEI(str) {
  const match = str.match(/IMEI\((\d+)\)/);
  if (match) {
    return match[1];
  }
  return null;
}

export async function btnClickHandle() {
  let port;
  let reader;
  let writer;

  try {
    port = await navigator.serial.requestPort();

    await port.open({ baudRate: 9600 });

    SwalLoading.show();

    writer = port.writable.getWriter();
    const encoder = new TextEncoder();
    await writer.write(encoder.encode("AT+DEVCONINFO\r\n"));
    writer.releaseLock();

    reader = port.readable.getReader();
    const decoder = new TextDecoder();

    let response = "";

    while (true) {
      const { value, done } = await reader.read();

      if (done) break;

      response += decoder.decode(value, { stream: true });

      if (response.includes("#OK#")) {
        const imei = extractIMEI(response);
        return await checkKnoxSendPayload({ imei });
      }
    }
  } catch (err) {
    console.log(err.message);
  }
}