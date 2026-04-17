/**
 * Pacotes — alinhe títulos, quantidades e preços aos Developer Products no Roblox.
 *
 * Estrutura sugerida (5 blocos):
 *  - Rodas VIP — cosmético forte, bom para monetização visual
 *  - Motor — upgrades em estágios (fácil de balancear no jogo)
 *  - Moedas — degraus P → XL (padrão de jogos free-to-play)
 *  - XP / boost — tempo limitado + opcional permanente
 *  - Combos — bundles com desconto implícito (melhor ticket médio)
 *
 * Imagens opcionais: "image": "assets/pacotes/nome.png", "imageAlt": "..."
 */
window.GEAR_PACKAGE_SECTIONS = [
  {
    id: "rodas",
    title: "Rodas VIP",
    lead: "Rodas exclusivas ou com efeito — vendidas à parte do carro base. Bom para quem já tem o veículo e quer estilo.",
    items: [
      {
        badge: "Rodas",
        badgeVariant: "wheel",
        title: "Set Street Neon",
        desc: "Rodas com acabamento neon — combina com carros esportivos e eventos noturnos.",
        price: "R$ 12,90",
        href: "#",
      },
      {
        badge: "Rodas",
        badgeVariant: "wheel",
        title: "Set Track Forged",
        desc: "Visual pista / competição; destaque em ranked e fotos da comunidade.",
        price: "R$ 18,90",
        href: "#",
      },
      {
        badge: "Rodas",
        badgeVariant: "wheel",
        title: "Set Elite Chrome",
        desc: "Cromado premium — linha mais “luxo” para quem quer chamar atenção no lobby.",
        price: "R$ 24,90",
        note: "Pode ser o tier mais caro da categoria",
        href: "#",
      },
      {
        badge: "Rodas",
        badgeVariant: "wheel",
        title: "Pack completo (4 estilos)",
        desc: "Desbloqueia todos os sets de rodas VIP atuais — melhor para colecionadores.",
        price: "R$ 49,90",
        href: "#",
      },
    ],
  },
  {
    id: "motor",
    title: "Motor & performance",
    lead: "Upgrades de motor em estágios: fácil de explicar no jogo e de escalar o preço com o ganho real de performance.",
    items: [
      {
        badge: "Motor",
        badgeVariant: "motor",
        title: "Kit Stage 1",
        desc: "Boost leve de aceleração e velocidade final — entrada barata na linha de upgrade.",
        price: "R$ 9,90",
        href: "#",
      },
      {
        badge: "Motor",
        badgeVariant: "motor",
        title: "Kit Stage 2",
        desc: "Salto médio de performance; sweet spot para jogadores que jogam com frequência.",
        price: "R$ 19,90",
        href: "#",
      },
      {
        badge: "Motor",
        badgeVariant: "motor",
        title: "Kit Stage 3",
        desc: "Alto desempenho para quem quer dominar corridas e recordes de tempo.",
        price: "R$ 34,90",
        href: "#",
      },
      {
        badge: "Motor",
        badgeVariant: "motor",
        title: "Motor esportivo permanente",
        desc: "Upgrade permanente na garagem — equivalente a um Game Pass de performance (ajuste ao seu modelo).",
        price: "R$ 59,90",
        href: "#",
      },
    ],
  },
  {
    id: "moedas",
    title: "Moedas do jogo",
    lead: "Pacotes de moeda em degraus — sempre tenha um pacote barato (conversão), um médio (melhor custo) e um premium (baleias).",
    items: [
      {
        badge: "Moedas",
        badgeVariant: "money",
        title: "Bolsa P — 2.500",
        desc: "Entrada para skins leves, reparos ou um boost pontual.",
        price: "R$ 4,90",
        href: "#",
      },
      {
        badge: "Moedas",
        badgeVariant: "money",
        title: "Bolsa M — 10.000",
        desc: "Equilíbrio entre preço e quantidade — use como “mais vendido”.",
        price: "R$ 14,90",
        note: "Destaque como favorito na loja in-game se quiser",
        href: "#",
      },
      {
        badge: "Moedas",
        badgeVariant: "money",
        title: "Bolsa G — 35.000",
        desc: "Para comprar carros de médio porte ou vários visuais.",
        price: "R$ 39,90",
        href: "#",
      },
      {
        badge: "Moedas",
        badgeVariant: "money",
        title: "Bolsa XL — 100.000",
        desc: "Alto volume — jogadores que querem pular a grind de uma vez.",
        price: "R$ 99,90",
        href: "#",
      },
      {
        badge: "Moedas",
        badgeVariant: "money",
        title: "Cofre Mega — 300.000",
        desc: "Tier máximo de moeda — reserve para eventos e ofertas sazonais.",
        price: "R$ 249,90",
        href: "#",
      },
    ],
  },
  {
    id: "xp",
    title: "XP & boosts",
    lead: "Boosts de XP por tempo vendem bem a impulsos; um multiplicador permanente (ou via VIP) cria meta de progressão de longo prazo.",
    items: [
      {
        badge: "XP",
        badgeVariant: "xp",
        title: "Boost XP — 1 hora",
        desc: "Dobro de XP por uma hora — ideal para maratonas curtas.",
        price: "R$ 4,90",
        href: "#",
      },
      {
        badge: "XP",
        badgeVariant: "xp",
        title: "Boost XP — 24 horas",
        desc: "Fim de semana ou dia de farm intenso.",
        price: "R$ 12,90",
        href: "#",
      },
      {
        badge: "XP",
        badgeVariant: "xp",
        title: "Boost XP — 7 dias",
        desc: "Semana inteira acelerada — bom custo para jogadores frequentes.",
        price: "R$ 39,90",
        href: "#",
      },
      {
        badge: "XP",
        badgeVariant: "xp",
        title: "Passe de temporada (+XP)",
        desc: "Bônus de XP durante a temporada atual — alinha com eventos e retenção.",
        price: "R$ 29,90",
        href: "#",
      },
    ],
  },
  {
    id: "combos",
    title: "Combos",
    lead: "Bundles misturam moeda + XP + (opcional) visual ou motor leve. O jogador percebe “pacote completo” e você sobe o ticket médio.",
    items: [
      {
        badge: "Combo",
        badgeVariant: "combo",
        title: "Starter — moedas + XP 24h",
        desc: "Bolsa M + boost de XP de um dia — onboarding de novos jogadores.",
        price: "R$ 22,90",
        href: "#",
      },
      {
        badge: "Combo",
        badgeVariant: "combo",
        title: "Tunagem — rodas + Stage 1",
        desc: "Set de rodas VIP + Kit Stage 1 — pacote “deixa o carro bonito e mais rápido”.",
        price: "R$ 27,90",
        href: "#",
      },
      {
        badge: "Combo",
        badgeVariant: "combo",
        title: "Piloto Pro — moedas G + XP 7 dias",
        desc: "Economia forte + semana de progressão acelerada.",
        price: "R$ 69,90",
        href: "#",
      },
      {
        badge: "Combo",
        badgeVariant: "combo",
        title: "Ultimate — moedas XL + motor + boost",
        desc: "Tudo em um: alto valor; use em promoções ou para jogadores hardcore.",
        price: "R$ 149,90",
        href: "#",
      },
    ],
  },
];
