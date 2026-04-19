import "./site.css";
import { mountGame } from "./game/view";

const mount = document.querySelector<HTMLElement>("#practice-mount");
if (mount) {
  mountGame(mount);
}
