const setMetaToken = ({ token }) => {
  let meta = document.head.querySelector('meta[name="knox-token"]');

  if (!meta) {
    meta = document.createElement("meta");
    meta.name = "jwt-token";
    document.head.appendChild(meta);
  }

  meta.content = token;
};

export const generateJwtToken = async () => {
  try {
    const user = api.getCurrentUser();
    if (!user) return;
    const response = await fetch("https://checkknox.com/api/generate-jwt", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
      },
      body: JSON.stringify({ u: user.username }),
    });

    const { data } = await response.json();
    if (!data) return;
    setMetaToken(data);
  } catch (error) {
    console.error("Generate JWT failed:", error);
  }
};