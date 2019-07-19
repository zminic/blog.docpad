---
title: "Learning React"
layout: "post"
date: 2019-07-19
summary: "I have avoided larning React for a long time, finally it is time to attempt to create sample project."
summaryImage: "/images/posts/react.jpg"
tags: [javascript, react, typescript]
---

I have avoided larning React for a long time, partially because I don't use it in company projects (we use homegrown stack) and partially because I was telling myself that it was yet another framework I could easily learn when I need it.

Now I have decided it's time for me to learn different stack altogether and to bring myself up to speed on all new tools. So in the next few posts you can expect to see more about react, nodejs and postgresql.

After going through react docs I have found example showing simple tic-tac-toe game and explaining why react is a good fit for this kind of applications. Seeing game, board and squares I immediately remembered game I created in javascript - Minesweeper. So in this post I will explain how I created a Minesweeper game in react.

You can find demo [here](https://therealmofcode.com/minesweeper-react/), and source code [here](https://github.com/zminic/minesweeper-react).

<img src="/images/posts/minesweeper-react.png" alt="Minesweeper react" />

## Where to start? ##

Every time when I test new library/framework I try to find good starting point for creating new application. In JS world when you start new project you need to think about tool-chain you will use. Do you want to use some kind of transpiling (typescript, babel), bundling, minification, dev server, hot reload...

It really becomes overwhelming if you do not have some kind of guidance of best practices for given framework. For React I was completely blown away by [Create React App](https://reactjs.org/docs/create-a-new-react-app.html#create-react-app). By executing following command I was able to get up and running in under a minute:

```
npx create-react-app my-app
cd my-app
yarn run start
```

When you run this command React tooling creates for you sample application with toolchain already set-up. Right away you have development server up and running with hot reload and webpack is completely transparent, you can only use npm (or yarn) to do start and build. Amazing!

To set-up project which uses typescript you would use following command:

```
npx create-react-app my-app --typescript
```

Simple and right to the point.

## Structuring application ##

Maybe the hardest thing with React applications is to create proper structure of components. To decide whether component is stateless or statefull and which component should hold state.

I have found a good post that describes this process in detail [here](https://reactjs.org/docs/thinking-in-react.html).

For the Minesweeper game I have decided to structure it in following way:

1. Square component - Represents a basic square in the board. This component is stateless only has props and its job is to add correct classes to button element and to handle events.
2. Board component - Again stateless component that gets array of squares it needs to render. Its job is to render squares properly and to handle events.
3. Game component - This is statefull component that keeps track of various game elements such as board, stats, levels. All events on Square and Board are propagated to Game component which has the main game logic.

## Game logic ##

I will not cover game logic in detail, you can find more info in this blog post: [building minesweeper game using javascript](/posts/2012/11/building-minesweeper-game-using-javascript-html-css.html).

The main idea in this React application is to listen to click event on Square (I call it Reveal in code) and then we mutate list of squares and React can figure out what to update on screen.

I had to change reveal code to be more inline with React recommendations to make state immutable, and to update state only when needed. Because of this I had to create "revealInternal" method that could work recursively on squares, and to mutate state only when everything is finished.

Of course there is more to it than that but if we look at it from the React perspective this is all that it's doing.

In my github repo you can find commented code with explained logic behind initializing board (planting mines and calculating distances), revealing square (regular and auto mode), flagging square, timer, stats and more.

## Summary ##

I'm really satisfied with the result application. Development experience has been great, I could focus on coding the actual game instead of trying to figure out how to configure tool stack.

I think that React is really suitable for this kind of games because it can efficiently calculate exactly what needs to be updated in DOM (using its virtual DOM feature) and to make minimal updates.