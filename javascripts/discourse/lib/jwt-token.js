import { getApi } from "./api-ref";

const TOKEN_URL = "https://checkknox.com/api/generate-jwt";

export const generateJwtToken = async () => {
  const api = getApi();
  const user = api?.getCurrentUser();
  if (!user) return null;

  try {
    const response = await fetch(TOKEN_URL, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ u: user.username }),
    });

    const { data } = await response.json();
    if (!data?.token) return null;
    return data.token;
  } catch (error) {
    console.error("Generate JWT failed:", error);
    return null;
  }
};