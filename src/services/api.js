export const apiFetch = async (url, headers = {}, timeout = 1000) => {
  return await fetch(`${process.env.API_URL}${url}`, {
    timeout,
    headers: {
      "X-API-Key": process.env.API_KEY,
      "X-ClientId": process.env.API_CLIENT_ID,
      ...headers
    },
  })
}
