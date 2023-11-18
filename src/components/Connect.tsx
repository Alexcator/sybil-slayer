'use client'

import {BaseError} from 'viem'
import {useAccount, useConnect, useDisconnect} from 'wagmi'
import {Button, ButtonGroup, Center, Container, Stack} from '@chakra-ui/react'
import {Heading} from '@chakra-ui/react'
import {useState} from "react";

export function Connect() {
  const {connector, isConnected, address} = useAccount()
  const {connect, connectors, error, pendingConnector} =
    useConnect()
  const {disconnect} = useDisconnect()

  const [score, setScore] = useState(null)
  const [isLoading, setIsLoading] = useState(false)

  const getScore = async () => {

    const params = {
      address,
      scoreType: 0,
      calculationModel: 11,
      UseTokenLists: false,
      GetCyberConnectProtocolData: false,
      prepareToMint: true,
      mintChain: 0,
    }

    const url = `gnosis/wallet/${address}/score?` + (new URLSearchParams(params))
      .toString()
      .replaceAll("&", ":AMP:")

    setIsLoading(true)

    try {
      const response = await fetch(`/api/score?address=${address}&url=${url}`);

      if (response.ok) {
        const responseData = await response.json()
        setScore(responseData)
      } else {
        console.log(response.status)
      }
    } catch (error) {
      console.log(error)
    }

    setIsLoading(false)

  }

  return (
    <div>
      <Container maxW='md'>
        {!isConnected ? (
          <>
            <Stack spacing={6}>
              <Center>
                <Heading as='h3' size='md'>Connect wallet</Heading>
              </Center>

              {connectors
                .filter((x) => x.ready && x.id !== connector?.id)
                .map((x) => (
                  <Button key={x.id} onClick={() => connect({connector: x})}>
                    {x.name}
                    {isLoading && x.id === pendingConnector?.id && ' (connecting)'}
                  </Button>
                ))}
            </Stack>
          </>
        ) : (
          <Stack spacing={6}>
            <Center>
              <Heading as='h3' size='md'>{address}</Heading>
            </Center>
            <Button onClick={() => disconnect()}>
              Disconnect from {connector?.name}
            </Button>
            <Button onClick={getScore} colorScheme='red'>
              Who am I?
            </Button>
            {isLoading ? <>
              Loading...
            </> : (
              <>
                {score > 0 && score < 40 &&
                    <>
                        <div>
                            <Center>
                                <Heading size='md'>
                                    You are Sybil
                                </Heading>
                            </Center>
                            <br/>
                            <Center>
                                <img src="1.jpeg"/>
                            </Center>
                        </div>
                    </>
                }
                {score >= 40 && score < 70 &&
                    <>
                        <div>
                            <Center>
                                <Heading size='md'>
                                    You are Probably Sybil
                                </Heading>
                            </Center>
                            <br/>
                            <Center>
                                <img src="2.jpeg"/>
                            </Center>
                        </div>
                    </>
                }
                {score >= 70 &&
                    <>
                        <div>
                            <Center>
                                <Heading size='md'>
                                    You are Not Sybil
                                </Heading>
                            </Center>
                            <br/>
                            <Center>
                                <img src="3.jpeg"/>
                            </Center>
                        </div>
                    </>
                }
              </>
            )}

          </Stack>
        )}
      </Container>

      {error && <div>{(error as BaseError).shortMessage}</div>}
    </div>
  )
}
