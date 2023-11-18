import {Providers} from './providers'
import '../scss/app.scss'
import {Box, ChakraProvider} from "@chakra-ui/react";

export default function RootLayout({
                                     children,
                                   }: {
  children: React.ReactNode
}) {
  return (
    <html lang="en">
    <body>
    <ChakraProvider>
      <Providers>
        {children}
      </Providers>
    </ChakraProvider>
    </body>
    </html>
  )
}
