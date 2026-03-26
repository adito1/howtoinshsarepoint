import { Version } from '@microsoft/sp-core-library';
import { BaseClientSideWebPart } from '@microsoft/sp-webpart-base';

import styles from './DemoWebPartWebPart.module.scss';

export interface IDemoWebPartWebPartProps {
}

export default class DemoWebPartWebPart extends BaseClientSideWebPart<IDemoWebPartWebPartProps> {
  public render(): void {
    this.domElement.innerHTML = `<div class="${ styles.demoWebPart }"></div>`;
  }

  protected onInit(): Promise<void> {
    return super.onInit();
  }

  protected get dataVersion(): Version {
    return Version.parse('1.0');
  }
}
