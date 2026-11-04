import { createContext, useContext } from "react"
import pt from "../../../locales/pt-br.json"
import en from "../../../locales/en-us.json"

export const LocaleContext = createContext("pt-br")

export function useTranslation() {
  const locale = useContext(LocaleContext)
  const dictionary = locale.toLowerCase() === "en-us" || locale.toLowerCase() === "en" ? en.ui : pt.ui
  return (key: keyof typeof pt.ui) => dictionary[key] || pt.ui[key]
}
