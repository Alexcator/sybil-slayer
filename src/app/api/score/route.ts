import { ethers } from "ethers";
import {apiFetch} from "../../../services/api";
import {NextRequest, NextResponse} from "next/server";

const sendError = function (message: string) {
  return NextResponse.json({error: message, status: 500})
}

export async function GET(request: NextRequest) {
  const searchParams = request.nextUrl.searchParams

  const address = searchParams.get('address')
  const url = searchParams.get('url')

  if (!address) return sendError('No address provided');
  if (!url) return sendError('Wrong address provided');

  try {
    const response = await apiFetch(`${url.replaceAll(":AMP:", "&")}`, {}, 999999)
    if (!response.ok) throw new Error(`${response.status}: ${response.statusText}`);

    let scoreData = await response.json()

    let score = Math.round(scoreData.data.score * 100)

    return NextResponse.json(score)
  } catch (error) {
    return NextResponse.json({
      error: `${error.message}`,
      status: 500,
    })
  }
};
